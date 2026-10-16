class ApiTokenPolicy < ApplicationPolicy
  allow :admin, to: %i[index new create destroy]
end
