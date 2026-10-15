class RawMaterial < ApplicationRecord
  PACKAGES = %w[cx sc kg un].freeze

  acts_as_tenant :company

  belongs_to :supplier, optional: true
  has_many :products, dependent: :restrict_with_error
  has_many :stock_counts, dependent: :destroy

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :company_id }
  validates :purchase_package, inclusion: { in: PACKAGES }

  # Fator ausente gera alerta, não erro.
  def missing_factor?
    multiply_factor.blank?
  end
end
