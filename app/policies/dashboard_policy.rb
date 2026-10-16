class DashboardPolicy < ApplicationPolicy
  allow :admin, :office, to: :show
end
