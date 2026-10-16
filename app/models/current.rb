class Current < ActiveSupport::CurrentAttributes
  attribute :session, :request_id, :ip_address
  delegate :user, to: :session, allow_nil: true
end
