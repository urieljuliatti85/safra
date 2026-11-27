class OrderLine < ApplicationRecord
  # Crivo (ou pente, 30 ovos) e dúzia vêm da R1.21 (D9).
  UNITS = %w[kg un cx mç crivo dz].freeze
  # Teto de digitação, bem abaixo do que cabe em decimal(10,3): um número maior é erro de digitação.
  MAX_QUANTITY = 1_000_000
  # Marca de andamento na Programação (R3.4, D35), escolhida pelo Gerente de Produção. A quantidade não se divide.
  SCHEDULE_MARKS = { "produce" => "produzir no dia", "ready" => "já pronto" }.freeze
  SCHEDULE_SYMBOLS = { "produce" => "□", "ready" => "•" }.freeze

  acts_as_tenant :company
  include Auditable
  audited except: %w[order_id]

  def audit_label = "#{product&.name} · #{order&.customer&.short_name} · entrega #{delivery_date.strftime('%d/%m/%Y')}"

  belongs_to :order
  belongs_to :product

  validates :delivery_date, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0, less_than: MAX_QUANTITY }
  validates :unit, inclusion: { in: UNITS }
  validates :schedule_mark, inclusion: { in: SCHEDULE_MARKS.keys }
  validates :actual_kg, numericality: { greater_than_or_equal_to: 0, less_than: MAX_QUANTITY }, allow_nil: true
  validate :execution_date_before_delivery

  # Até quantos dias antes da entrega o item pode ser adiantado.
  EXECUTION_DAYS = 6

  # Dia de execução (esteira simplificada, passo 4): o que o Gerente de Produção escolheu ou, sem escolha, o dia padrão.
  # A Planilha de Produção e a compra seguem esse dia.
  def execution_on = execution_date || default_execution_on

  # Sem escolha: a véspera da entrega (3.2) ou, no produto de preparo no dia (R3.7: temperos, folhagens, Yaksoba), o
  # próprio dia da entrega. Os ingredientes de uma mistura seguem o dia do item da mistura.
  def default_execution_on = product&.prepared_on_delivery_day? ? delivery_date : delivery_date - 1

  # Os dias que o Gerente de Produção pode escolher: da entrega até EXECUTION_DAYS dias antes.
  def execution_options = ((delivery_date - EXECUTION_DAYS)..delivery_date).to_a

  delegate :customer, to: :order

  # Peso real da pesagem (R2.6, R2.7), em kg. Aceita vírgula decimal ("12,5"); vazio é ainda não pesado.
  def actual_kg=(value)
    super(value.is_a?(String) ? value.strip.tr(",", ".").presence : value)
  end

  private

  def execution_date_before_delivery
    return if execution_date.nil? || delivery_date.nil? || execution_options.include?(execution_date)

    errors.add(:execution_date, "deve ser entre #{EXECUTION_DAYS} dias antes da entrega e o dia da entrega")
  end
end
