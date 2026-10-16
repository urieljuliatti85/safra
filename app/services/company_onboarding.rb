# Cria uma empresa nova com o primeiro administrador (senha provisória, mostrada uma vez) e o catálogo inicial:
# só os cortes padrão ou uma cópia do catálogo de outra empresa. Tudo ou nada.
class CompanyOnboarding
  STANDARD_CUTS = Rails.root.join("db/seeds_data/cortes.yml")

  Result = Data.define(:company, :admin, :password, :errors) do
    def ok? = errors.empty?
  end

  def initialize(name:, admin_name:, admin_email:, catalog_from: nil)
    @name = name
    @admin_name = admin_name
    @admin_email = admin_email
    @catalog_from = catalog_from
  end

  def call
    password = User.generate_provisional_password
    company = Company.new(name: @name.to_s.strip)
    admin = nil
    Company.transaction do
      company.save!
      admin = company.users.new(name: @admin_name.to_s.strip, email_address: @admin_email, role: "admin",
                                password: password, password_confirmation: password, must_change_password: true)
      admin.save!
      @catalog_from ? CompanyCatalogCopier.new(from: @catalog_from, to: company).call : load_standard_cuts(company)
    end
    Result.new(company: company, admin: admin, password: password, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(company: nil, admin: nil, password: nil, errors: [ "#{e.record.is_a?(User) ? 'Administrador' : 'Empresa'}: #{e.record.errors.full_messages.to_sentence}" ])
  end

  private

  def load_standard_cuts(company)
    Current.set(session: nil) do
      ActsAsTenant.with_tenant(company) do
        YAML.safe_load_file(STANDARD_CUTS).each do |row|
          Cut.create!(code: row["codigo"], name: row["nome"], sector: row["setor"], sector_name: row["nome_setor"], lead_days: row["antecedencia_dias"])
        end
      end
    end
  end
end
