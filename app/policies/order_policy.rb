class OrderPolicy < ApplicationPolicy
  allow :admin, :office, to: %i[index update received cancel_items]
end
