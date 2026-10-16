class AddDeliveryAddressToCustomers < ActiveRecord::Migration[8.1]
  def change
    change_table :customers, bulk: true do |t|
      t.string :address        # rua e número
      t.string :district       # bairro
      t.string :city
      t.string :state, limit: 2
      t.string :postal_code, limit: 8
      t.decimal :latitude, precision: 9, scale: 6
      t.decimal :longitude, precision: 9, scale: 6
      t.time :delivery_from
      t.time :delivery_until
      t.text :delivery_notes
    end
  end
end
