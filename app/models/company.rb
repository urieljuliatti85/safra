class Company < ApplicationRecord
  include Auditable
  has_many :users, dependent: :restrict_with_error

  validates :name, presence: true
  validates :raw_lead_days, numericality: { only_integer: true, in: 0..5 }
end
