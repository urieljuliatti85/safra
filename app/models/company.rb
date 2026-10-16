class Company < ApplicationRecord
  include Auditable
  has_many :users, dependent: :restrict_with_error

  validates :name, presence: true
  scope :active, -> { where(active: true) }

  # Suspende a empresa: ninguém dela entra e as sessões abertas caem. Os dados ficam como estão.
  def suspend!
    update!(active: false)
    Session.where(user_id: users.select(:id)).destroy_all
  end
  validates :raw_lead_days, numericality: { only_integer: true, in: 0..5 }
end
