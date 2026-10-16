class CustomerAliasPolicy < ApplicationPolicy
  allow :admin, :office, to: %i[create destroy]
end
