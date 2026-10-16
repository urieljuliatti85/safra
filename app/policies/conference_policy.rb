class ConferencePolicy < ApplicationPolicy
  allow :admin, :office, to: %i[show sheets new create destroy]
end
