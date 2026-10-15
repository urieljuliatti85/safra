class UserPolicy < ApplicationPolicy
  allow :admin, to: %i[index new create edit update reset_password]
end
