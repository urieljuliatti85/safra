require "test_helper"

class PushSenderTest < ActiveSupport::TestCase
  # Inscrição gravada antes da validação do endpoint: não sai POST para fora dos serviços de push (SSRF).
  test "endpoint fora dos serviços de push não é chamado e a inscrição é dada como vencida" do
    subscription = ActsAsTenant.with_tenant(company) do
      PushSubscription.new(endpoint: "http://169.254.169.254/latest/meta-data", p256dh: PushTestHelper::VALID_P256DH, auth: PushTestHelper::VALID_AUTH)
    end
    called = false
    original = WebPush.method(:payload_send)
    WebPush.define_singleton_method(:payload_send) { |**| called = true }

    assert_equal :gone, PushSender.deliver(subscription, { title: "x" })
    assert_not called
  ensure
    WebPush.define_singleton_method(:payload_send, original) if original
  end
end
