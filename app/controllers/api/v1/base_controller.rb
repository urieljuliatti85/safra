# Base da API v1: autentica pelo token (Authorization: Bearer safra_...), isola a empresa da chave,
# separa leitura de escrita e responde sempre em JSON { error: { code, message } }.
module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_token!
      around_action :scope_to_company
      rate_limit to: 300, within: 1.minute, by: -> { request.authorization.to_s.first(80).presence || request.remote_ip },
                 with: -> { render_error(:too_many_requests, "rate_limited", "Muitas requisições. Tente de novo em instantes.") }

      rescue_from ActiveRecord::RecordNotFound do |error|
        render_error(:not_found, "not_found", error.message.presence || "Não encontrado.")
      end
      rescue_from ActionController::BadRequest do |error|
        render_error(:bad_request, "bad_request", error.message)
      end
      rescue_from ActionController::ParameterMissing do |error|
        render_error(:bad_request, "parameter_missing", "Parâmetro obrigatório ausente: #{error.param}.")
      end

      private

      def authenticate_token!
        plain = request.authorization.to_s[/\ABearer (\S+)\z/, 1]
        @api_token = ApiToken.authenticate(plain)
        return render_error(:unauthorized, "unauthorized", "Token ausente, inválido ou revogado.") unless @api_token && @api_token.company.active

        @api_token.touch_usage!
        Current.api_token = @api_token
        Current.request_id = request.request_id
        Current.ip_address = request.remote_ip
      end

      def scope_to_company(&block)
        ActsAsTenant.with_tenant(@api_token.company, &block)
      end

      def require_write!
        render_error(:forbidden, "forbidden", "Este token é só de leitura.") unless @api_token.write?
      end

      def current_company = @api_token.company

      def date_param(key, default = nil)
        text = params[key].presence
        return default unless text

        Date.iso8601(text.to_s)
      rescue Date::Error
        raise ActionController::BadRequest, "Data inválida em #{key}: use AAAA-MM-DD."
      end

      def render_error(status, code, message, details: nil)
        body = { error: { code: code, message: message } }
        body[:error][:details] = details if details
        render json: body, status: status
      end
    end
  end
end
