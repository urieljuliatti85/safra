# Saldo de produto pronto (R3.8, D39): o que já está pronto na câmara, contado por produto e dia, na unidade do
# produto. A compra abate do pedido antes do fator de conversão.
class ProductStockCount < ApplicationRecord
  acts_as_tenant :company
  include Auditable

  def audit_label = "Contagem de #{product&.name} pronto em #{date.strftime('%d/%m/%Y')}"

  belongs_to :product

  validates :date, presence: true, uniqueness: { scope: :product_id }
  validates :quantity, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000 }

  # Aceita vírgula decimal ("12,5"). Troca na atribuição porque a validação de número lê o texto original.
  def quantity=(value)
    super(value.is_a?(String) ? value.strip.tr(",", ".") : value)
  end
end
