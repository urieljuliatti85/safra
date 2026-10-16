class CutPolicy < ApplicationPolicy
  allow :admin, :office, to: %i[index new create edit update destroy]
end
