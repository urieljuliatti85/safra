class HomePolicy < ApplicationPolicy
  allow :admin, :office, :production, to: :show
end
