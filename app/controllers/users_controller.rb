# Administração de usuários: só o admin cria, muda papel, desativa e redefine senha (sem e-mail: a senha
# provisória aparece uma única vez, na tela, para o admin repassar).
class UsersController < ApplicationController
  authorize_resource :user
  before_action :load_user, only: %i[edit update reset_password]

  def index
    @users = current_company.users.order(:name)
    @last_access = last_access(@users.map(&:id))
  end

  def new
    @user = current_company.users.new(role: "office")
  end

  def create
    @user = current_company.users.new(params.require(:user).permit(:name, :email_address))
    @user.role = params.dig(:user, :role) # validado pela inclusão em User::ROLES
    provisional = User.generate_provisional_password
    @user.assign_attributes(password: provisional, password_confirmation: provisional, must_change_password: true)
    if @user.save
      redirect_to users_path, notice: provisional_notice(@user, provisional, "criado")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @user.name = params.dig(:user, :name)
    # Ninguém tira o próprio acesso: sempre sobra o admin que está editando.
    if @user != current_user
      @user.role = params.dig(:user, :role) if params.dig(:user, :role)
      @user.active = ActiveModel::Type::Boolean.new.cast(params.dig(:user, :active))
    end
    if @user.save
      @user.sessions.destroy_all if @user.saved_change_to_active? && !@user.active?
      redirect_to users_path, notice: "Usuário #{@user.name} atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def reset_password
    return redirect_to(users_path, alert: "Para trocar a sua senha, use \"Trocar senha\" no menu.") if @user == current_user

    provisional = @user.reset_to_provisional_password!
    redirect_to users_path, notice: provisional_notice(@user, provisional, "redefinida")
  end

  private

  # Último login pelo histórico (redefinir a senha apaga as sessões, mas o histórico fica); sessões cobrem logins
  # de antes do histórico existir.
  def last_access(ids)
    logins = AuditLog.where(action: "login", user_id: ids).group(:user_id).maximum(:created_at)
    sessions = Session.where(user_id: ids).group(:user_id).maximum(:created_at)
    logins.merge(sessions) { |_id, login, session| [ login, session ].max }
  end

  def load_user
    @user = current_company.users.find(params[:id])
  end

  def provisional_notice(user, password, action)
    "Usuário #{user.name} #{action}. Senha provisória: #{password} (aparece só agora; #{user.name} troca no primeiro acesso)."
  end
end
