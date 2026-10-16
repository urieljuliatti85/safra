class RulePolicy < ApplicationPolicy
  allow :admin, :office, to: %i[show update]
end
