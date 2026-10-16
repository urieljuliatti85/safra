class AuditLogPolicy < ApplicationPolicy
  allow :admin, to: :index
end
