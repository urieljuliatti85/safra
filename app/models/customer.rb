class Customer < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  has_many :aliases, class_name: "CustomerAlias", dependent: :destroy
  has_many :orders, dependent: :restrict_with_error

  validates :code, :name, :short_name, presence: true
  validates :code, uniqueness: { scope: :company_id }
end
