# Quem vê a produção pode ativar os avisos do próprio aparelho.
class PushSubscriptionPolicy < ApplicationPolicy
  allow :admin, :office, :production, to: %i[show create destroy]
end
