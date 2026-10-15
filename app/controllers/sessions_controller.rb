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
      redirect_to after_authentication_url
    else
      redirect_to new_session_path(email_address: params[:email_address]), alert: "E-mail ou senha incorretos."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
