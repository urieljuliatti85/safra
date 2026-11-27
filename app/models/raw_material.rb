class RawMaterial < ApplicationRecord
  PACKAGES = %w[cx sc kg un].freeze

  acts_as_tenant :company
  include Auditable

  belongs_to :supplier, optional: true
  has_many :products, dependent: :restrict_with_error
  has_many :stock_counts, dependent: :destroy
  has_many :sheet_aliases, dependent: :destroy

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :company_id }
  validates :purchase_package, inclusion: { in: PACKAGES }
  validates :multiply_factor, :kg_per_package, :kg_per_peeled_box, numericality: { greater_than: 0, less_than: 1000 }, allow_nil: true
  validates :units_per_package, numericality: { only_integer: true, greater_than: 0, less_than: 10_000 }, allow_nil: true

  # Aceita vírgula decimal ("1,35") e campo vazio (fica sem valor). Troca na atribuição porque a validação de
  # número lê o texto original, antes da conversão.
  %i[multiply_factor kg_per_package kg_per_peeled_box units_per_package].each do |attribute|
    define_method(:"#{attribute}=") { |value| super(value.is_a?(String) ? value.strip.tr(",", ".").presence : value) }
  end

  # Fator ausente gera alerta, não erro.
  def missing_factor?
    multiply_factor.blank?
  end

  # Pedido nesta unidade vira compra sem fator (R3.10, D40): fruta em unidade comprada por unidade (melancia), ou
  # comprada em caixa ou saco com as unidades por embalagem cadastradas (laranja, 100 por caixa).
  def converts_units?(unit)
    unit == "un" && (purchase_package == "un" || units_per_package.present?)
  end

  # Comprada em caixa ou saco sem o peso da embalagem: a compra não vira número de caixas.
  def missing_package_weight?
    kg_per_package.blank? && %w[cx sc].include?(purchase_package)
  end
end
