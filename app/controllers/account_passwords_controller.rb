# Troca de senha da própria pessoa. É o único destino liberado enquanto a senha for provisória.
class AccountPasswordsController < ApplicationController
  skip_before_action :require_password_change
  skip_after_action :verify_authorized

  def edit
  end

  def update
    user = current_user
    provisional = user.must_change_password
    if !provisional && !user.authenticate(params[:current_password].to_s)
      @error = "A senha atual não confere."
    elsif params[:password].to_s != params[:password_confirmation].to_s
      @error = "A confirmação não é igual à senha nova."
    elsif params[:password].to_s.length < 8
      @error = "A senha nova precisa ter pelo menos 8 caracteres."
    end
    return render :edit, status: :unprocessable_entity if @error

    user.update!(password: params[:password], password_confirmation: params[:password_confirmation], must_change_password: false)
    user.sessions.where.not(id: Current.session.id).destroy_all # derruba os outros aparelhos
    AuditLog.record_event("password_changed", user: user, request: request)
    redirect_to home_path_for(user), notice: "Senha alterada."
  end
end
