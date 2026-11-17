# Ingrediente de uma mistura (R1.19, R1.20; D18): o percentual é sobre o peso da mistura.
class ProductComponent < ApplicationRecord
  acts_as_tenant :company

  belongs_to :product
  belongs_to :component, class_name: "Product"

  validates :percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :component_id, uniqueness: { scope: :product_id }
  # Medida do ingrediente na mistura (R1.20, D30), quando é diferente da referência do corte; vazia, vale a do produto.
  validates :measure, length: { maximum: 200 }
  normalizes :measure, with: ->(value) { value.strip.presence }
end
