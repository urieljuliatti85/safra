# Grava a contagem da câmara fria de um dia: { raw_material_id => texto em kg }.
# Texto vazio apaga a contagem (não contado); 0 é câmara vazia. Qualquer erro desfaz tudo.
# Usado pela tela de Estoque e pela API.
class StockCountSaver
  Result = Data.define(:errors, :changed) do
    def ok? = errors.empty?
  end

  def initialize(date:, counts:)
    @date = date
    @counts = counts
  end

  def call
    errors = []
    changed = 0
    StockCount.transaction do
      RawMaterial.where(id: @counts.keys).find_each do |raw_material|
        text = @counts[raw_material.id.to_s].to_s.strip
        existing = StockCount.find_by(raw_material: raw_material, date: @date)
        if text.empty?
          existing&.destroy!
          changed += 1 if existing
          next
        end

        record = existing || StockCount.new(raw_material: raw_material, date: @date)
        record.kg = text
        next unless record.new_record? || record.changed?

        if record.save
          changed += 1
        else
          errors << "#{raw_material.name}: #{record.errors.full_messages.to_sentence}"
        end
      end
      raise ActiveRecord::Rollback if errors.any?
    end
    Result.new(errors: errors, changed: errors.any? ? 0 : changed)
  end
end
