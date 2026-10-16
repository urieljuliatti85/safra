class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  set_current_tenant_through_filter
  before_action :set_tenant
  before_action :require_password_change
  before_action :set_audit_context
  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  helper_method :current_user, :current_company

  # authorize_resource :order  =>  authorize :order, "#{action_name}?" antes de cada ação do controller.
  def self.authorize_resource(key)
    before_action { authorize key, :"#{action_name}?" }
  end

  private

  def current_user
    Current.user
  end

  def current_company
    Current.user.company
  end

  # Quem está agindo e de onde, para o histórico; o request_id agrupa o que veio de uma mesma ação.
  def set_audit_context
    Current.request_id = request.request_id
    Current.ip_address = request.remote_ip
  end

  def set_tenant
    set_current_tenant(current_company) if Current.user
  end

  # Senha provisória: a pessoa só usa o sistema depois de trocar.
  def require_password_change
    return unless Current.user&.must_change_password

    redirect_to edit_account_password_path, alert: "Escolha uma senha nova para continuar."
  end

  # Tela de abertura de cada papel: produção cai direto na lista do dia.
  def home_path_for(user)
    user.production? ? production_path : orders_path
  end
  helper_method :home_path_for

  def forbidden
    redirect_to home_path_for(current_user), alert: "Você não tem acesso a essa tela."
  end

  def date_param(key, default)
    Date.iso8601(params[key].to_s)
  rescue Date::Error
    default
  end
end
