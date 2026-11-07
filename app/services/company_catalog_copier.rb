# Copia o catálogo de uma empresa para outra: fornecedores, cortes, matérias-primas (com fatores e peso da
# embalagem), produtos e exceções de antecedência. Não copia clientes, apelidos, pedidos, estoque nem dias de compra:
# isso é da operação de cada empresa. Não deixa rastro no histórico (é a montagem inicial da empresa).
class CompanyCatalogCopier
  def initialize(from:, to:)
    @from = from
    @to = to
  end

  def call
    source = ActsAsTenant.with_tenant(@from) do
      { suppliers: Supplier.all.to_a, cuts: Cut.all.to_a, raw_materials: RawMaterial.all.to_a, products: Product.all.to_a, rules: ProductionRule.all.to_a,
        components: ProductComponent.all.to_a }
    end
    Current.set(session: nil) do
      ActsAsTenant.with_tenant(@to) do
        suppliers = source[:suppliers].to_h { |s| [ s.id, Supplier.create!(name: s.name) ] }
        cuts = source[:cuts].to_h { |c| [ c.id, Cut.create!(c.attributes.slice("code", "name", "sector", "sector_name", "lead_days", "reference_measure")) ] }
        raw_materials = source[:raw_materials].to_h do |rm|
          attributes = rm.attributes.slice("code", "name", "multiply_factor", "kg_per_package", "kg_per_peeled_box", "purchase_package", "note")
          [ rm.id, RawMaterial.create!(attributes.merge("supplier" => suppliers[rm.supplier_id])) ]
        end
        products = source[:products].to_h do |p|
          attributes = p.attributes.slice("code", "name", "product_group", "unit")
          [ p.id, Product.create!(attributes.merge("raw_material" => raw_materials.fetch(p.raw_material_id), "cut" => cuts[p.cut_id])) ]
        end
        source[:rules].each { |rule| ProductionRule.create!(product: products.fetch(rule.product_id), lead_days: rule.lead_days) }
        source[:components].each do |item|
          ProductComponent.create!(product: products.fetch(item.product_id), component: products.fetch(item.component_id), percentage: item.percentage)
        end
      end
    end
    @to.update!(raw_lead_days: @from.raw_lead_days)
  end
end
