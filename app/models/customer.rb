class Customer < ApplicationRecord
  STATES = %w[AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO].freeze

  acts_as_tenant :company
  include Auditable

  has_many :aliases, class_name: "CustomerAlias", dependent: :destroy
  has_many :orders, dependent: :restrict_with_error

  normalizes :state, with: ->(value) { value.strip.upcase.presence }
  normalizes :postal_code, with: ->(value) { value.gsub(/\D/, "").presence }
  normalizes :address, :district, :city, :delivery_notes, with: ->(value) { value.strip.presence }

  validates :code, :name, :short_name, presence: true
  validates :code, uniqueness: { scope: :company_id }
  validates :state, inclusion: { in: STATES, message: "deve ser a sigla de um estado (ex.: SP)" }, allow_nil: true
  validates :postal_code, format: { with: /\A\d{8}\z/, message: "deve ter 8 dígitos" }, allow_nil: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validate :delivery_window_in_order

  # Para roteirizar basta rua e número com a cidade; o resto melhora a precisão.
  def address_complete? = address.present? && city.present?

  # "Rua das Flores, 120 - Centro, Vitória/ES, CEP 29010-000"
  def full_address
    place = [ city, state ].compact.join("/")
    cep = postal_code && "CEP #{postal_code[0, 5]}-#{postal_code[5, 3]}"
    [ [ address, district ].compact.join(" - ").presence, place.presence, cep ].compact.join(", ").presence
  end

  def delivery_window_text
    return unless delivery_from || delivery_until

    [ delivery_from&.strftime("%H:%M") || "…", delivery_until&.strftime("%H:%M") || "…" ].join(" às ")
  end

  private

  def delivery_window_in_order
    return unless delivery_from && delivery_until && delivery_until.strftime("%H%M") <= delivery_from.strftime("%H%M")

    errors.add(:delivery_until, "deve ser depois do início da janela")
  end
end
