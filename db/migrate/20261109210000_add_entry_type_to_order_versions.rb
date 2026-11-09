# Tipo de pedido de cada versão (R1.29 a R1.33, D22): pedido novo, alteração ou extra. Vazio nas versões antigas,
# nas que o sistema grava sozinho (antes do primeiro salvamento, restaurar, desfazer) e na API sem o tipo.
class AddEntryTypeToOrderVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :order_versions, :entry_type, :string
  end
end
