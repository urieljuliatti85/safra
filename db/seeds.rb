# Carrega os cadastros e os pedidos da semana de 12/10/2026 a partir de db/seeds_data/*.yml.
# Idempotente: pode rodar várias vezes. Os pedidos da semana são recriados a cada execução.
require "yaml"

data_dir = Rails.root.join("db/seeds_data")
product_groups = { "processado" => "processed", "in_natura" => "raw", "fruta" => "fruit" }
week_start = Date.new(2026, 10, 12)
# Dias de compra na CEASA da semana (planilha 03 - COMPRAS CEASA e protótipo).
purchase_dates = [ Date.new(2026, 10, 13), Date.new(2026, 10, 15), Date.new(2026, 10, 19) ]

load_yaml = ->(name) { YAML.safe_load_file(data_dir.join(name), permitted_classes: [ Date ]) }

company = Company.find_or_create_by!(name: "Hortifruti Modelo")

ActsAsTenant.with_tenant(company) do
  ActiveRecord::Base.transaction do
    suppliers = load_yaml.call("fornecedores.yml").to_h do |row|
      [ row["nome"], Supplier.find_or_create_by!(name: row["nome"]) ]
    end

    raw_materials = load_yaml.call("materias_primas.yml").to_h do |row|
      raw_material = RawMaterial.find_or_initialize_by(code: row["codigo"])
      raw_material.update!(
        name: row["nome"],
        supplier: row["fornecedor"] && suppliers.fetch(row["fornecedor"]),
        multiply_factor: row["fator_multiplicar"],
        kg_per_package: row["kg_por_embalagem"],
        kg_per_peeled_box: row["kg_por_caixa_descascada"],
        purchase_package: row["embalagem_compra"],
        note: row["observacao"]
      )
      [ row["codigo"], raw_material ]
    end

    cuts = load_yaml.call("cortes.yml").to_h do |row|
      cut = Cut.find_or_initialize_by(code: row["codigo"])
      cut.update!(
        name: row["nome"],
        sector: row["setor"],
        sector_name: row["nome_setor"],
        lead_days: row["antecedencia_dias"]
      )
      [ row["codigo"], cut ]
    end

    products = load_yaml.call("produtos.yml").to_h do |row|
      product = Product.find_or_initialize_by(code: row["codigo"])
      product.update!(
        name: row["nome"],
        product_group: product_groups.fetch(row["grupo"]),
        raw_material: raw_materials.fetch(row["materia_prima"]),
        cut: row["corte"] && cuts.fetch(row["corte"]),
        unit: row["unidade"]
      )
      [ row["codigo"], product ]
    end

    customers = load_yaml.call("clientes.yml").to_h do |row|
      customer = Customer.find_or_initialize_by(code: row["codigo"])
      customer.update!(name: row["nome"], short_name: row["nome_curto"], order_source: row["origem_pedido"])
      [ row["codigo"], customer ]
    end

    load_yaml.call("apelidos.yml").each do |row|
      CustomerAlias.find_or_initialize_by(customer: customers.fetch(row["cliente"]), name_in_order: row["nome_no_pedido"])
                   .update!(product: products.fetch(row["produto"]))
    end

    purchase_dates.each { |date| PurchaseDay.find_or_create_by!(date: date) }

    orders = customers.transform_values { |customer| Order.find_or_create_by!(customer: customer, week_start: week_start) }
    orders.each_value { |order| order.lines.destroy_all }
    load_yaml.call("pedidos_2026-10-12.yml").each do |row|
      orders.fetch(row["cliente"]).lines.create!(
        product: products.fetch(row["produto"]),
        delivery_date: row["entrega"],
        quantity: row["quantidade"],
        unit: row["unidade"],
        note: row["observacao"]
      )
    end
  end
end

puts "Seeds carregados: #{Company.count} empresa, #{ActsAsTenant.with_tenant(company) { [ RawMaterial.count, Product.count, Customer.count, OrderLine.count ] }.join(' / ')} (matérias-primas / produtos / clientes / linhas de pedido)"
