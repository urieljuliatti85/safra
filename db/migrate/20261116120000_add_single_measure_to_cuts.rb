# Medida única do corte (R2.11, D26): o palito sai sempre 40 × 10 mm, mesmo quando o pedido traz outra medida.
# Marca o corte "palitos" de cada empresa. A medida de referência só é trocada onde ainda é a do seed antigo (ou vazia, NULL ou ""):
# o seed não altera corte já cadastrado, e uma medida editada na tela não é sobrescrita.
class AddSingleMeasureToCuts < ActiveRecord::Migration[8.1]
  OLD_MEASURE = "30 a 50 mm × 10 a 12 mm (vagem: 8 a 10 mm); usual 40 × 10 mm; 10 × 10 × 60 mm quando o cliente pede".freeze
  NEW_MEASURE = "40 × 10 mm".freeze

  def up
    add_column :cuts, :single_measure, :boolean, null: false, default: false
    execute "UPDATE cuts SET single_measure = TRUE WHERE code = 'palitos'"
    execute <<~SQL.squish
      UPDATE cuts SET reference_measure = #{connection.quote(NEW_MEASURE)}
      WHERE code = 'palitos' AND (reference_measure IS NULL OR reference_measure IN ('', #{connection.quote(OLD_MEASURE)}))
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE cuts SET reference_measure = #{connection.quote(OLD_MEASURE)}
      WHERE code = 'palitos' AND reference_measure = #{connection.quote(NEW_MEASURE)}
    SQL
    remove_column :cuts, :single_measure
  end
end
