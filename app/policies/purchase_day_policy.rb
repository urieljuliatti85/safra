class PurchaseDayPolicy < ApplicationPolicy
  allow :admin, :office, to: %i[create destroy]
end
