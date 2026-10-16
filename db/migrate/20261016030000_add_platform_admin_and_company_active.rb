class AddPlatformAdminAndCompanyActive < ActiveRecord::Migration[8.1]
  def change
    # Dono da plataforma: cria e suspende empresas. Não é um papel da empresa e não se concede pela tela.
    add_column :users, :platform_admin, :boolean, null: false, default: false
    # Empresa suspensa: ninguém dela entra, e as sessões abertas caem.
    add_column :companies, :active, :boolean, null: false, default: true

    reversible do |direction|
      direction.up do
        # Hoje há uma empresa só: o primeiro administrador vira o dono da plataforma.
        execute "UPDATE users SET platform_admin = TRUE WHERE id = (SELECT id FROM users WHERE role = 'admin' ORDER BY id LIMIT 1)"
      end
    end
  end
end
