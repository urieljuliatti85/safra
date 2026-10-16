# Chaves de API e a empresa dos seeds para os specs de request.
module ApiHelpers
  def modelo
    @modelo ||= Company.find_by!(name: "Hortifruti Modelo")
  end

  # Consultas do próprio spec (fora da requisição) precisam de empresa; a API da requisição resolve a dela pela chave.
  def in_company(company = modelo, &block)
    ActsAsTenant.with_tenant(company, &block)
  end

  def issue_token(scope: "read", company: modelo, name: "Spec")
    ApiToken.issue!(company: company, name: name, scope: scope).last
  end

  def other_company
    @other_company ||= Company.create!(name: "Outra Empresa").tap do |company|
      ActsAsTenant.with_tenant(company) { Customer.create!(company: company, code: "x1", name: "Cliente de Outra Empresa", short_name: "Outra") }
    end
  end
end

RSpec.configure { |config| config.include ApiHelpers }
