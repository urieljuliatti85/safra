class OrderVersionPolicy < ApplicationPolicy
  allow :admin, :office, to: %i[show restore]
end
