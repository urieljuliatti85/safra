class Order < ApplicationRecord
  acts_as_tenant :company

  belongs_to :customer
  has_many :lines, class_name: "OrderLine", dependent: :destroy
  has_many :versions, class_name: "OrderVersion", dependent: :delete_all

  validates :week_start, presence: true, uniqueness: { scope: :customer_id }

  # A semana do pedido vai de segunda a domingo (R1.6, D6).
  def self.week_dates(week_start) = week_start..(week_start + 6)

  def week_dates = self.class.week_dates(week_start)
end
