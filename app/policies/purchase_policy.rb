class PurchasePolicy < ApplicationPolicy
  allow :admin, :office, to: %i[show publish]
end
