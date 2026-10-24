class OrderPolicy < ApplicationPolicy
  allow :admin, :office, to: %i[index update copy_previous]
end
