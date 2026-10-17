# Pronto para atender: o banco responde. O /up do Rails só diz que o app subiu; este é o healthcheck do deploy,
# para uma versão que não alcança o banco não entrar no ar. Sem login e sem detalhes na resposta.
class ReadinessController < ActionController::Base
  def show
    if database_up?
      render json: { status: "ok" }
    else
      render json: { status: "unavailable" }, status: :service_unavailable
    end
  end

  private

  def database_up?
    ActiveRecord::Base.connection_pool.with_connection { |connection| connection.select_value("SELECT 1") } == 1
  rescue StandardError => error
    Rails.logger.error("Readiness: banco indisponível (#{error.class})")
    false
  end
end
