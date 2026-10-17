require "test_helper"

class ReadinessTest < ActionDispatch::IntegrationTest
  test "responde 200 sem login quando o banco responde" do
    get readiness_check_path
    assert_response :success
    assert_equal({ "status" => "ok" }, response.parsed_body)
  end

  test "responde 503, sem detalhes do erro, quando o banco não responde" do
    pool = ActiveRecord::Base.connection_pool
    pool.define_singleton_method(:with_connection) { |*| raise ActiveRecord::ConnectionNotEstablished, "senha=segredo host=interno" }
    begin
      get readiness_check_path
    ensure
      pool.singleton_class.send(:remove_method, :with_connection)
    end

    assert_response :service_unavailable
    assert_equal({ "status" => "unavailable" }, response.parsed_body)
    assert_no_match(/segredo|interno/, response.body)
  end

  test "o healthcheck do deploy aponta para o /ready" do
    assert_equal "/ready", JSON.parse(Rails.root.join("railway.json").read).dig("deploy", "healthcheckPath")
  end
end
