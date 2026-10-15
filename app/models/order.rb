class Order < ApplicationRecord
  acts_as_tenant :company

  belongs_to :customer
  has_many :lines, class_name: "OrderLine", dependent: :destroy

  validates :week_start, presence: true, uniqueness: { scope: :customer_id }
end
