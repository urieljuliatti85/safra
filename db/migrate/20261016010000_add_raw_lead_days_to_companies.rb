class AddRawLeadDaysToCompanies < ActiveRecord::Migration[8.1]
  def change
    # Antecedência da compra do in natura em relação à entrega (hipótese: véspera).
    add_column :companies, :raw_lead_days, :integer, null: false, default: 1
  end
end
