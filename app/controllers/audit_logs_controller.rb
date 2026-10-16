# Histórico de quem alterou o quê, só para o administrador. Somente leitura.
class AuditLogsController < ApplicationController
  authorize_resource :audit_log

  TYPES = %w[RawMaterial Product Customer CustomerAlias Supplier Cut ProductionRule Company PurchaseDay StockCount User OrderLine OrderImport ProductionPlan PurchasePlan].freeze

  def index
    @filters = {
      user_id: params[:user_id].presence, type: (params[:type] if TYPES.include?(params[:type])), id: params[:id].presence,
      q: params[:q].to_s.strip.presence, from: date_param(:from, nil), to: date_param(:to, nil)
    }
    @result = AuditTrail.new(filters: @filters, page: params[:page]).call
    @users = current_company.users.order(:name)
    @types = TYPES.map { |type| [ type.constantize.model_name.human, type ] }.sort
  end
end
