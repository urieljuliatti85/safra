class ConferencePolicy < ApplicationPolicy
  allow :admin, :office, to: %i[show sheets]
end
