class OrderImportPolicy < ApplicationPolicy
  allow :admin, :office, to: %i[new create show apply undo grid settings]
end
