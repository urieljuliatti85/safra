class Current < ActiveSupport::CurrentAttributes
  attribute :session, :request_id, :ip_address, :api_token
  delegate :user, to: :session, allow_nil: true
end
