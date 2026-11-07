class Order < ApplicationRecord
  acts_as_tenant :company

  belongs_to :customer
  has_many :lines, class_name: "OrderLine", dependent: :destroy
  has_many :versions, class_name: "OrderVersion", dependent: :delete_all

  validates :week_start, presence: true, uniqueness: { scope: :customer_id }

  # A semana do pedido vai de segunda a domingo (R1.6, D6).
  def self.week_dates(week_start) = week_start..(week_start + 6)

  def week_dates = self.class.week_dates(week_start)

  # Prazo do pedido semanal: 15h da quinta-feira anterior à semana das entregas (R1.4, D7).
  # Cliente com pedido mensal (a Nutrir manda o mês 10 dias antes, R1.5) não segue esse prazo.
  def deadline = (week_start - 4).in_time_zone.change(hour: 15)

  def late? = received_at.present? && !customer.monthly_orders? && received_at > deadline
end
