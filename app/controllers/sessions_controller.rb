class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  skip_before_action :require_password_change
  skip_after_action :verify_authorized
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Muitas tentativas. Espere alguns minutos e tente de novo." }

  def new
    redirect_to root_path if authenticated?
  end

  def create
    user = User.active.authenticate_by(params.permit(:email_address, :password))
    if user
      start_new_session_for user
      AuditLog.record_event("login", user: user, request: request)
      redirect_to after_authentication_url
    else
      record_failed_login
      redirect_to new_session_path(email_address: params[:email_address]), alert: "E-mail ou senha incorretos."
    end
  end

  def destroy
    AuditLog.record_event("logout", user: Current.user, request: request) if Current.user
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  # Tentativa errada de uma pessoa cadastrada fica no histórico dela. E-mail desconhecido não tem empresa: fica de fora.
  def record_failed_login
    user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
    return unless user

    AuditLog.record_event("login_failed", user: user, request: request,
                          details: { "Motivo" => [ nil, user.active? ? "senha incorreta" : "usuário desativado" ] })
  end
end
