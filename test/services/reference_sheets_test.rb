require "test_helper"

# Leitura das planilhas feitas à mão (02 e 03) e comparação com o que o Safra calcula, com o motivo de cada diferença.
# Os arquivos em test/fixtures/files são sintéticos, no formato das planilhas da empresa.
class ReferenceSheetsTest < ActiveSupport::TestCase
  WEEK = Date.new(2026, 10, 12)

  setup { ActsAsTenant.current_tenant = company }
  teardown { ActsAsTenant.current_tenant = nil }

  def read(name) = ReferenceSheets::Reader.new(file_fixture(name).to_s).call(WEEK..(WEEK + 6))

  def import(*names)
    files = names.map { |name| ReferenceSheets::Importer::File.new(path: file_fixture(name).to_s, filename: name) }
    ReferenceSheets::Importer.new(company: company, user: user_for(:office), week_start: WEEK, files: files).call
  end

  def row(comparison, label, section: nil)
    comparison.rows.find { |r| r.label == label && (section.nil? || r.section == section) } || flunk("sem linha #{label}")
  end

  test "lê os blocos da planilha de produção e deixa de fora instruções, separadores e abas de outra semana" do
    tabs = read("planilha_producao.ods")
    assert_equal [ [ "production", Date.new(2026, 10, 13) ] ], tabs.map { |tab| [ tab.kind, tab.date ] }
    lines = tabs.first.lines.map { |line| [ line.section, line.label, line.quantity&.to_f, line.unit ] }
    assert_includes lines, [ "descascador", "BATATA BATIDA", 10.0, "cx" ]
    assert_includes lines, [ "aprontes", "ALFACE LAVADA", 3.0, "cx" ]
    assert_includes lines, [ "cortes", "CENOURA RALADA", 3.0, "kg" ]
    assert_includes lines, [ "aprontes", "VAGEM ARRUMADA", nil, nil ] # "1.½" fica como texto
    labels = lines.map(&:second)
    assert_not labels.any? { |label| label.include?("ABRIR") || label.include?("(") || label.include?("//") }
  end

  test "lê a planilha de compras com a unidade de cada linha" do
    lines = read("compras_ceasa.ods").first.lines.to_h { |line| [ line.label, [ line.quantity&.to_f, line.unit ] ] }
    assert_equal [ 20.0, "cx" ], lines["CENOURA"]
    assert_equal [ 500.0, "g" ], lines["PIMENTA MALAGUETA"]
    assert_equal [ 5.0, "un" ], lines["ABACAXI"]
    assert_equal [ nil, nil ], lines["QUIABO"] # "meia caixa"
    assert_not lines.key?("TOMATE") # sem quantidade
  end

  test "reconhece os nomes da planilha pelo cadastro, pelo estado da matéria-prima e pelos apelidos do seed" do
    matcher = ReferenceSheets::Matcher.new
    assert_equal "abobora_cubos", matcher.call("ABÓBORA CUBOS", "product").record.code
    assert_equal "abobora_lascas", matcher.call("ABÓBORA EM LASCAS", "product").record.code
    assert_equal "baroa", matcher.call("BAROA DESCASCADA", "raw_material").record.code
    assert_equal "batata_doce", matcher.call("BATATA DOCE DESCASCADA", "raw_material").record.code
    assert_equal "repolho_picado", matcher.call("REPOLHO BR. PICADO", "product").record.code
    assert_equal :alias, matcher.call("BANANA TERRA MÉDIA", "raw_material").by
    assert_nil matcher.call("COISA NOVA PICADA", "product")
  end

  test "importar troca os números do dia e mostra a comparação com os motivos" do
    sheets = import("planilha_producao.ods", "compras_ceasa.ods")
    assert_equal [ %w[production 2026-10-13], %w[purchase 2026-10-13] ], sheets.map { |s| [ s.kind, s.date.iso8601 ] }
    assert_equal "TERÇA 13-10-26", sheets.first.tab_name

    comparison = SheetComparison.new(company, dates: WEEK..(WEEK + 6))
    ralada = row(comparison, "Cenoura ralada")
    assert ralada.ok?
    assert_equal "un", row(comparison, "Laranja descascada").unit
    assert_equal :not_modeled, row(comparison, "Batata inglesa", section: "descascador").reason
    assert_equal :not_comparable, row(comparison, "Vagem", section: "aprontes").status
    assert_equal 65, row(comparison, "Banana da terra").planilha # 45 kg + 20 kg da média, somados pelo apelido
    assert_equal :not_comparable, row(comparison, "Quiabo", section: "compras").status
    assert_equal [ "COISA NOVA PICADA" ], comparison.unmatched.map(&:label)
    assert_equal :unmatched, row(comparison, "COISA NOVA PICADA").status

    import("planilha_producao.ods")
    assert_equal 1, ReferenceSheet.where(kind: "production", date: "2026-10-13").count
  end

  test "cada envio fica no histórico e importar de novo cria a versão seguinte sem apagar a anterior" do
    import("planilha_producao.ods", "compras_ceasa.ods")
    import("planilha_producao.ods")

    imports = SheetImport.newest_first.to_a
    assert_equal [ [ "planilha_producao.ods" ], %w[planilha_producao.ods compras_ceasa.ods] ], imports.map(&:filenames)
    assert_equal user_for(:office), imports.first.user
    assert_equal WEEK, imports.first.week_start

    sheet = ReferenceSheet.find_by!(kind: "production", date: "2026-10-13")
    assert_equal [ 1, 2 ], sheet.versions.map(&:version)
    assert_equal [ imports.last, imports.first ], sheet.versions.map(&:sheet_import)
    first, second = sheet.versions
    assert_equal first.lines, second.lines
    assert_equal sheet.lines.size, second.parsed_lines.size
    assert_empty second.changes_from_previous
    assert_equal [ 1 ], ReferenceSheet.find_by!(kind: "purchase", date: "2026-10-13").versions.map(&:version)
  end

  test "a versão mostra o que entrou, saiu e mudou em relação à anterior" do
    import("programacao.ods")
    sheet = ReferenceSheet.find_by!(kind: "schedule", date: "2026-10-13")
    lines = sheet.versions.last.lines
    cenoura = lines.index { |line| line["group_label"] == "BOM PASTOR" && line["label"] == "CENOURA EM PALITOS" } || flunk("sem cenoura")
    changed = lines.map(&:dup)
    removed = changed.delete_at(lines.size - 1)
    changed[cenoura] = changed[cenoura].merge("quantity_text" => "9", "quantity" => "9.0")
    changed << { "section" => "programacao", "label" => "ALHO PICADO", "quantity_text" => "1", "quantity" => "1.0", "group_label" => "BOM PASTOR",
                 "delivery_date" => "2026-10-13" }
    version = sheet.versions.create!(version: 2, lines: changed)

    changes = version.changes_from_previous.index_by(&:label)
    assert_equal 3, changes.size
    assert_equal [ :changed, "9" ], [ changes["CENOURA EM PALITOS"].kind, changes["CENOURA EM PALITOS"].after ]
    assert_equal [ :added, nil, "1" ], [ changes["ALHO PICADO"].kind, changes["ALHO PICADO"].before, changes["ALHO PICADO"].after ]
    assert_equal :removed, changes[removed["label"]].kind
    assert_equal Date.new(2026, 10, 13), changes["ALHO PICADO"].delivery_date
  end

  test "toda diferença que entra no placar tem um motivo" do
    comparison = SheetComparison.new(company)
    differences = comparison.rows.select { |r| r.scored? && !r.ok? }
    assert_not_empty differences
    assert differences.all?(&:reason)
    assert_equal differences.size, comparison.reasons.sum(&:last)
  end

  test "antecedência só explica a diferença quando o número aparece em outro dia" do
    comparison = SheetComparison.new(company, dates: WEEK..(WEEK + 6))
    aipim = row(comparison, "Aipim em cubinhos")
    assert_equal [ :only_sheet, :lead_time ], [ aipim.status, aipim.reason ]
    assert_match "12/10", aipim.detail
    abobora = comparison.rows.find { |r| r.label == "Abóbora em cubos" && r.date == Date.new(2026, 10, 13) }
    assert_equal :unexplained, abobora.reason
  end

  test "lê os blocos da programação com cliente e dia de entrega" do
    tabs = read("programacao.ods")
    assert_equal %w[schedule schedule], tabs.map(&:kind)
    lines = tabs.first.lines
    assert_equal [ "BOM PASTOR", Date.new(2026, 10, 12) ], [ lines.first.group_label, lines.first.delivery_date ]
    assert_equal [ "ALFACE PICADA" ], lines.select { |line| line.group_label == "CENTRAL" }.map(&:label) # o bloco vai até o próximo cabeçalho
    assert_not lines.any? { |line| line.label.include?("EMBALADAS") || line.quantity == 999.5 }
  end

  test "reconhece clientes da programação e abreviações das planilhas" do
    matcher = ReferenceSheets::Matcher.new
    assert_equal "hbp", matcher.call("BOM PASTOR", "customer").record.code
    assert_equal "hnorte", matcher.call("CENTRAL", "customer").record.code
    assert_equal "batata_inteira", matcher.call("BATATA INTEIRA DESC.", "product").record.code
    assert_equal "repolho_picado", matcher.call("REPOLHO BR. PICADO", "product").record.code
  end

  test "programação: vale a aba mais recente e cada diferença diz o motivo" do
    import("programacao.ods")
    comparison = SheetComparison.new(company, dates: WEEK..(WEEK + 6))
    hbp = comparison.schedule_rows.select { |r| r.section == "Bom Pastor" && r.date == WEEK }.index_by(&:label)
    assert hbp["Batata em cubinhos"].ok?
    assert_equal [ :different, :unexplained ], [ hbp["Cenoura em palitos"].status, hbp["Cenoura em palitos"].reason ]
    assert_equal [ :only_system, :not_in_sheet ], [ hbp["Chuchu em cubos"].status, hbp["Chuchu em cubos"].reason ]

    vix = comparison.schedule_rows.select { |r| r.section == "Horiz. Sul" }.index_by(&:label)
    assert vix["Vagem em palitos"].ok?, "a aba de 13/10 substitui a de 12/10 para o mesmo cliente e dia"
    assert_equal :other_product, vix["Chuchu em cubos"].reason
    assert_match "Chuchu em cubinhos", vix["Chuchu em cubos"].detail
    assert_equal :unmatched, vix["PRODUTO MISTERIOSO"].status
    assert comparison.scores[:schedule][1].positive?
  end

  test "nota da equipe explica a diferença enquanto os números não mudam" do
    import("programacao.ods")
    find = ->(c) { c.schedule_rows.find { |r| r.section == "Bom Pastor" && r.date == WEEK && r.label == "Cenoura em palitos" } }
    row = find.call(SheetComparison.new(company, dates: WEEK..(WEEK + 6)))
    ComparisonNote.create!(kind: "schedule", section: row.section, date: row.date, item: row.code, note: "Cliente pediu 1 kg a menos por telefone",
                           planilha: row.planilha, sistema: row.sistema)

    noted = find.call(SheetComparison.new(company, dates: WEEK..(WEEK + 6)))
    assert_equal [ :noted, "Cliente pediu 1 kg a menos por telefone" ], [ noted.reason, noted.detail ]
    assert noted.explained?

    OrderLine.joins(order: :customer).find_by!(customers: { code: "hbp" }, delivery_date: WEEK, product: row.record).update!(quantity: 5)
    stale = find.call(SheetComparison.new(company, dates: WEEK..(WEEK + 6)))
    assert stale.note_stale
    assert_equal :unexplained, stale.reason
  end

  test "compra sem kg por embalagem aponta o cadastro" do
    comparison = SheetComparison.new(company, dates: WEEK..(WEEK + 6))
    mamao = comparison.purchase_rows.find { |r| r.code == "mamao" && r.date == Date.new(2026, 10, 13) }
    assert_equal [ :only_sheet, :missing_package ], [ mamao.status, mamao.reason ]
  end
end
