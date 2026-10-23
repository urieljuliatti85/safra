# Diferença entre a última versão enviada e o que o sistema calcula agora.
class PlanDiff
  # sector: setor do produto na produção (nil nas compras); serve para avisar só quem acompanha aquele setor.
  Change = Data.define(:label, :unit, :before, :after, :sector) do
    def kind
      if before.nil? then :added
      elsif after.nil? then :removed
      else :changed
      end
    end
  end

  def self.production(plan, result)
    sent = plan.items.includes(product: :cut).to_h { |i| [ [ i.product_id, i.unit ], [ i.product.name, i.quantity, i.product.sector ] ] }
    current = result.items.to_h { |i| [ [ i.product.id, i.unit ], [ i.product.name, i.quantity, i.product.sector ] ] }
    compare(sent, current)
  end

  # Compara a quantidade líquida a comprar (kg ou unidade do pedido).
  def self.purchase(plan, needs)
    sent = plan.items.includes(:raw_material).to_h { |i| [ [ i.raw_material_id, i.unit ], [ i.raw_material.name, i.kg ] ] }
    current = needs.to_h { |n| [ [ n.raw_material.id, n.unit ], [ n.raw_material.name, n.net_kg ] ] }
    compare(sent, current)
  end

  def self.compare(sent, current)
    (sent.keys | current.keys).filter_map do |key|
      before = sent[key]&.at(1)
      after = current[key]&.at(1)
      next if before && after && (before - after).abs < 0.0005

      Change.new(label: (sent[key] || current[key]).first, unit: key.last, before: before, after: after, sector: (sent[key] || current[key]).at(2))
    end.sort_by(&:label)
  end
  private_class_method :compare
end
