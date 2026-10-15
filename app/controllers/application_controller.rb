class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  set_current_tenant_through_filter
  before_action :set_tenant

  helper_method :current_company

  private

  # Sem login ainda: a única empresa cadastrada (multiempresa entra com a autenticação).
  def current_company
    @current_company ||= Company.first!
  end

  def set_tenant
    set_current_tenant(current_company)
  end

  def date_param(key, default)
    Date.iso8601(params[key].to_s)
  rescue Date::Error
    default
  end
end
