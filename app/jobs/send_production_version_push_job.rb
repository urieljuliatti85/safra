# Avisa no celular quem acompanha os setores que mudaram na versão enviada. Roda na fila: o botão "Enviar" não espera as entregas.
class SendProductionVersionPushJob < ApplicationJob
  queue_as :default

  def perform(plan_id)
    return unless PushSender.enabled?

    plan = ActsAsTenant.without_tenant { ProductionPlan.sent.find_by(id: plan_id) }
    return unless plan

    ActsAsTenant.with_tenant(plan.company) do
      notice = ProductionVersionNotice.new(plan)
      next if notice.sectors.empty?

      # Quem acabou de enviar não precisa do aviso.
      subscriptions = PushSubscription.joins(:user).merge(User.active).where.not(user_id: plan.sent_by_id).includes(:user)
      subscriptions.find_each do |subscription|
        message = notice.message_for(subscription.sectors)
        next unless message

        subscription.destroy if PushSender.deliver(subscription, { title: message.title, options: message.options }) == :gone
      end
    end
  end
end
