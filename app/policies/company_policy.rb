# Empresas são do dono da plataforma: nem o administrador de uma empresa cria ou suspende outras.
class CompanyPolicy < ApplicationPolicy
  %i[index new create edit update].each do |action|
    define_method(:"#{action}?") { user.present? && user.platform_admin? }
  end
end
