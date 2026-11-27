class SchedulePolicy < ApplicationPolicy
  allow :admin, :office, :production, to: :show
  # A marca quadrado ou ponto é do Gerente de Produção (R3.4), que entra como escritório ou admin.
  allow :admin, :office, to: %i[mark execution]
end
