class OrderImportPolicy < ApplicationPolicy
  allow :admin, :office, to: %i[new create show apply grid settings]
end
