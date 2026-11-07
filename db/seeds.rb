# Carrega os cadastros e os pedidos da semana de 12/10/2026 a partir de db/seeds_data/*.yml.
# Só cria o que falta: nunca sobrescreve um cadastro editado na tela nem apaga pedidos já lançados, então é
# seguro rodar de novo. Para recomeçar do zero em desenvolvimento: bin/rails db:reset.
require "yaml"

data_dir = Rails.root.join("db/seeds_data")
product_groups = { "processado" => "processed", "in_natura" => "raw", "fruta" => "fruit" }
week_start = Date.new(2026, 10, 12)
# Dias de compra na CEASA da semana (planilha 03 - COMPRAS CEASA e protótipo).
purchase_dates = [ Date.new(2026, 10, 13), Date.new(2026, 10, 15), Date.new(2026, 10, 19) ]

load_yaml = ->(name) { YAML.safe_load_file(data_dir.join(name), permitted_classes: [ Date ]) }
# Registro novo recebe os atributos do YAML; um que já existe fica como está.
create_missing = lambda do |record, attributes|
  next record unless record.new_record?

  record.update!(attributes)
  record
end

company = Company.find_or_create_by!(name: "Hortifruti Modelo")

ActsAsTenant.with_tenant(company) do
  ActiveRecord::Base.transaction do
    suppliers = load_yaml.call("fornecedores.yml").to_h do |row|
      [ row["nome"], Supplier.find_or_create_by!(name: row["nome"]) ]
    end

    raw_materials = load_yaml.call("materias_primas.yml").to_h do |row|
      raw_material = create_missing.call(
        RawMaterial.find_or_initialize_by(code: row["codigo"]),
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
      cut = create_missing.call(
        Cut.find_or_initialize_by(code: row["codigo"]),
        name: row["nome"],
        sector: row["setor"],
        sector_name: row["nome_setor"],
        lead_days: row["antecedencia_dias"]
      )
      [ row["codigo"], cut ]
    end

    products = load_yaml.call("produtos.yml").to_h do |row|
      product = create_missing.call(
        Product.find_or_initialize_by(code: row["codigo"]),
        name: row["nome"],
        product_group: product_groups.fetch(row["grupo"]),
        raw_material: raw_materials.fetch(row["materia_prima"]),
        cut: row["corte"] && cuts.fetch(row["corte"]),
        unit: row["unidade"]
      )
      [ row["codigo"], product ]
    end

    customers = load_yaml.call("clientes.yml").to_h do |row|
      customer = create_missing.call(
        Customer.find_or_initialize_by(code: row["codigo"]),
        name: row["nome"], short_name: row["nome_curto"], order_source: row["origem_pedido"]
      )
      [ row["codigo"], customer ]
    end

    load_yaml.call("apelidos.yml").each do |row|
      create_missing.call(
        CustomerAlias.find_or_initialize_by(customer: customers.fetch(row["cliente"]), name_in_order: row["nome_no_pedido"]),
        product: products.fetch(row["produto"])
      )
    end

    purchase_dates.each { |date| PurchaseDay.find_or_create_by!(date: date) }

    load_yaml.call("apelidos_planilhas.yml").each do |row|
      target, records = { "produto" => [ "product", products ], "materia_prima" => [ "raw_material", raw_materials ], "cliente" => [ "customer", customers ] }.fetch(row["alvo"])
      record = records.fetch(row["codigo"])
      create_missing.call(
        SheetAlias.find_or_initialize_by(target: target, name: ReferenceSheets::Matcher.key(row["nome_na_planilha"])),
        label: row["nome_na_planilha"], target => record
      )
    end

    # Números das planilhas de 13 e 15/10/2026, só se o dia ainda não foi importado de um arquivo.
    reference = load_yaml.call("referencia_planilhas.yml")
    { "production" => reference.fetch("producao_planilha"), "purchase" => reference.fetch("compras_ceasa_planilha") }.each do |kind, days|
      days.each do |date, entries|
        sheet = ReferenceSheet.find_or_initialize_by(kind: kind, date: Date.parse(date.to_s))
        next unless sheet.new_record?

        sheet.update!(filename: "referencia_planilhas.yml")
        lines = if kind == "production"
          entries.map { |code, quantity| [ "cortes", products.fetch(code).name, quantity.to_s, quantity, products.fetch(code).unit ] }
        else
          entries.map do |entry|
            match = entry["quantidade"].to_s.match(/\A(\d+(?:[.,]\d+)?)\s*(cx|sc|kg|g|un)\z/)
            [ "compras", raw_materials.fetch(entry["materia_prima"]).name, entry["quantidade"].to_s, match && match[1].tr(",", "."), match && match[2] ]
          end
        end
        lines.each_with_index do |(section, label, text, quantity, unit), index|
          sheet.lines.create!(section: section, label: label, quantity_text: text, quantity: quantity, unit: unit, position: index)
        end
      end
    end

    # Os pedidos da semana só entram na primeira carga de cada cliente: depois disso quem manda é o que foi lançado.
    orders = customers.transform_values { |customer| Order.find_or_create_by!(customer: customer, week_start: week_start) }
    fresh_orders = orders.select { |_, order| order.previously_new_record? }
    load_yaml.call("pedidos_2026-10-12.yml").each do |row|
      next unless fresh_orders.key?(row["cliente"])

      # A semana do pedido vai de segunda a domingo (R1.6): entrega na segunda seguinte vai para o pedido daquela semana.
      order = orders.fetch(row["cliente"])
      delivery = Date.parse(row["entrega"].to_s)
      order = Order.find_or_create_by!(customer: order.customer, week_start: delivery.beginning_of_week) unless order.week_dates.cover?(delivery)
      order.lines.create!(
        product: products.fetch(row["produto"]),
        delivery_date: row["entrega"],
        quantity: row["quantidade"],
        unit: row["unidade"],
        note: row["observacao"]
      )
    end
  end
end

# Usuários. Em desenvolvimento e teste, um de cada papel com senha conhecida. Em produção, só o primeiro
# administrador, a partir de SAFRA_ADMIN_EMAIL e SAFRA_ADMIN_PASSWORD (a senha vale até o primeiro acesso).
demo_password = "safra-dev-123"
if Rails.env.development? || Rails.env.test?
  [ [ "Admin Safra", "admin@safra.local", "admin" ], [ "Escritório Safra", "escritorio@safra.local", "office" ],
    [ "Produção Safra", "producao@safra.local", "production" ] ].each do |name, email, role|
    user = User.find_or_initialize_by(email_address: email)
    user.update!(company: company, name: name, role: role, password: demo_password, password_confirmation: demo_password, active: true, must_change_password: false,
                 platform_admin: role == "admin")
  end
elsif ENV["SAFRA_ADMIN_EMAIL"].present? && ENV["SAFRA_ADMIN_PASSWORD"].present?
  user = User.find_or_initialize_by(email_address: ENV["SAFRA_ADMIN_EMAIL"])
  if user.new_record?
    user.update!(company: company, name: "Administrador", role: "admin", password: ENV["SAFRA_ADMIN_PASSWORD"], must_change_password: true, platform_admin: true)
  end
elsif !User.admins.exists?
  puts "Atenção: não há administrador. Defina SAFRA_ADMIN_EMAIL e SAFRA_ADMIN_PASSWORD e rode db:seed."
end

puts "Seeds carregados: #{Company.count} empresa, #{ActsAsTenant.with_tenant(company) { [ RawMaterial.count, Product.count, Customer.count, OrderLine.count ] }.join(' / ')} (matérias-primas / produtos / clientes / linhas de pedido)"
