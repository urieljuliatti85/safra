class IndicatorPolicy < ApplicationPolicy
  allow :admin, :office, to: :show
end
