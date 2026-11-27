# Grava a contagem de produto pronto de um dia (R3.8, D39): { product_id => texto na unidade do produto }.
# Texto vazio apaga a contagem (não contado); 0 é nada pronto. Qualquer erro desfaz tudo.
class ProductStockCountSaver
  def initialize(date:, counts:)
    @date = date
    @counts = counts
  end

  def call
    errors = []
    changed = 0
    ProductStockCount.transaction do
      Product.where(id: @counts.keys).where.not(product_group: "raw").find_each do |product|
        text = @counts[product.id.to_s].to_s.strip
        existing = ProductStockCount.find_by(product: product, date: @date)
        if text.empty?
          existing&.destroy!
          changed += 1 if existing
          next
        end

        record = existing || ProductStockCount.new(product: product, date: @date)
        record.quantity = text
        next unless record.new_record? || record.changed?

        if record.save
          changed += 1
        else
          errors << "#{product.name} pronto: #{record.errors.full_messages.to_sentence}"
        end
      end
      raise ActiveRecord::Rollback if errors.any?
    end
    StockCountSaver::Result.new(errors: errors, changed: errors.any? ? 0 : changed)
  end
end
