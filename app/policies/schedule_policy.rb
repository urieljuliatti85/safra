class SchedulePolicy < ApplicationPolicy
  allow :admin, :office, :production, to: :show
end
