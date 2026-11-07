# Medida de referência de cada corte (R1.15, D12). Preenche os cortes que já existem pelo código, só onde está vazio:
# o seed não altera corte já cadastrado.
class AddReferenceMeasureToCuts < ActiveRecord::Migration[8.1]
  MEASURES = {
    "cubinhos" => "10 × 10 × 10 mm",
    "cubos" => "20 × 20 × 20 mm",
    "cubos_g" => "50 × 50 × 50 mm",
    "lascas" => "30 × 50 mm",
    "laminas" => "5 mm de espessura, comprimento variável",
    "picado" => "3 a 10 mm",
    "fatiado" => "3 a 10 mm",
    "meia_lua" => "3 a 10 mm",
    "ralado" => "3 a 5 mm",
    "rodelas" => "3 a 30 mm de espessura, conforme a solicitação",
    "floretes" => "60 mm de referência, dimensões variáveis",
    "palitos" => "30 a 50 mm × 10 a 12 mm (vagem: 8 a 10 mm); usual 40 × 10 mm; 10 × 10 × 60 mm quando o cliente pede",
    "inteira_descascada" => "Sem corte; sem medida fixa",
    "gomos" => "Conforme o vegetal e a solicitação do cliente"
  }.freeze

  def up
    add_column :cuts, :reference_measure, :string
    MEASURES.each do |code, measure|
      execute "UPDATE cuts SET reference_measure = #{connection.quote(measure)} WHERE code = #{connection.quote(code)} AND reference_measure IS NULL"
    end
  end

  def down
    remove_column :cuts, :reference_measure
  end
end
