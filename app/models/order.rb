class Order < ApplicationRecord
  acts_as_tenant :company

  belongs_to :customer
  has_many :lines, class_name: "OrderLine", dependent: :destroy
  has_many :versions, class_name: "OrderVersion", dependent: :delete_all

  validates :week_start, presence: true, uniqueness: { scope: :customer_id }
end
