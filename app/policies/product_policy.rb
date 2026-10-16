class ProductPolicy < ApplicationPolicy
  allow :admin, :office, to: %i[index new create edit update destroy bulk_update]
end
