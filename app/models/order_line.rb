class OrderLine < ApplicationRecord
  UNITS = %w[kg un cx mç].freeze

  acts_as_tenant :company

  belongs_to :order
  belongs_to :product

  validates :delivery_date, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :unit, inclusion: { in: UNITS }

  delegate :customer, to: :order
end
