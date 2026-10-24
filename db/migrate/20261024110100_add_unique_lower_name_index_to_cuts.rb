# O modelo já recusa nome de corte repetido sem diferenciar maiúsculas; o índice garante isso também no banco.
class AddUniqueLowerNameIndexToCuts < ActiveRecord::Migration[8.1]
  def change
    add_index :cuts, "company_id, lower(name)", unique: true, name: "index_cuts_on_company_id_and_lower_name"
  end
end
