# Aparelho da pessoa logada nos avisos de produção. O endpoint do navegador identifica o aparelho.
class PushSubscriptionsController < ApplicationController
  authorize_resource :push_subscription

  def show
    subscription = current_user.push_subscriptions.find_by(endpoint: params[:endpoint])
    return head :not_found unless subscription

    render json: { sectors: subscription.sectors }
  end

  # Ativar ou trocar os setores. Aparelho compartilhado: quem ativa por último é o dono do aviso.
  def create
    subscription = ActsAsTenant.without_tenant { PushSubscription.find_or_initialize_by(endpoint: params[:endpoint].to_s) }
    subscription.assign_attributes(
      company: current_company, user: current_user, sectors: Array(params[:sectors]).map(&:to_s) & PushSubscription::SECTORS,
      p256dh: params.dig(:keys, :p256dh).to_s, auth: params.dig(:keys, :auth).to_s
    )
    if subscription.save
      render json: { sectors: subscription.sectors }
    else
      render json: { error: subscription.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    current_user.push_subscriptions.where(endpoint: params[:endpoint]).destroy_all
    head :no_content
  end
end
