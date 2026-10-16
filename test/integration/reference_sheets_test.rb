require "test_helper"

class ReferenceSheetsIntegrationTest < ActionDispatch::IntegrationTest
  ODS = "application/vnd.oasis.opendocument.spreadsheet".freeze

  setup { sign_in_as(user_for(:office)) }

  def upload(*names, week: "2026-10-14")
    post reference_sheets_path, params: { week: week, files: names.map { |name| fixture_file_upload(name, ODS) } }
  end

  test "a comparação mostra o placar, os motivos e a semana importada" do
    get conference_sheets_path
    assert_response :success
    assert_select "h1", "Sistema × planilhas"
    assert_select "nav[aria-label='Semanas importadas'] a[aria-current='true']", /12\/10 a 18\/10/
    assert_select ".cmp-score", /de 43 iguais/
    assert_select ".cmp-reasons li", /antecedência/
    assert_select "td.reason", /Falta kg por embalagem/
    assert_select "td.reason a[href*='materias-primas']", /completar cadastro/
  end

  test "importar as duas planilhas da semana leva à comparação com os nomes a ligar" do
    get new_reference_sheets_path
    assert_select "input[type=file][multiple][accept*='.ods']"

    upload("planilha_producao.ods", "compras_ceasa.ods")
    assert_redirected_to conference_sheets_path(week: "2026-10-12")
    follow_redirect!
    assert_select ".flash", /planilha de produção de 13\/10; compras ceasa de 13\/10/
    assert_select "#nomes", /COISA NOVA PICADA/
    assert_select "h2", /Produção · Ter 13\/10/
    assert_select "tr.cmp-section th", "Descascador"
  end

  test "ligar o nome da planilha a um produto vale daqui para frente" do
    upload("planilha_producao.ods")
    product = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "repolho_roxo_picado") }
    post sheet_aliases_path, params: { target: "product", label: "COISA NOVA PICADA", record_id: product.id, week: "2026-10-12" }
    assert_redirected_to conference_sheets_path(week: "2026-10-12")
    follow_redirect!
    assert_select ".flash", /"COISA NOVA PICADA" agora é Repolho roxo picado/
    assert_select "#nomes", count: 0
  end

  test "dá para tirar um nome da comparação" do
    upload("planilha_producao.ods")
    post sheet_aliases_path, params: { target: "product", label: "COISA NOVA PICADA", record_id: "ignore", week: "2026-10-12" }
    follow_redirect!
    assert_select ".flash", /fica fora da comparação/
    assert_select "#nomes", count: 0
    assert_select "td.name", text: "COISA NOVA PICADA", count: 0
  end

  test "arquivo sem abas da semana ou em outro formato volta com o motivo" do
    upload("planilha_producao.ods", week: "2026-11-02")
    assert_response :unprocessable_entity
    assert_select ".flash", /Nenhuma aba de 02\/11 a 08\/11/

    post reference_sheets_path, params: { week: "2026-10-12", files: [ fixture_file_upload("imagem_pedido.png", "image/png") ] }
    assert_response :unprocessable_entity
    assert_select ".flash", /Formato não aceito: imagem_pedido.png/
  end

  test "a programação aparece por dia de entrega e cliente" do
    upload("programacao.ods", "planilha_producao.ods", "compras_ceasa.ods")
    follow_redirect!
    assert_select ".flash", /programação de produção de 12\/10 e 13\/10/
    assert_select ".cmp-score", /Programação/
    assert_select "#dia-schedule-2026-10-16 tr.cmp-section th", "Horiz. Sul"
    assert_select "#dia-schedule-2026-10-16 td.reason", /Outro produto da mesma matéria-prima: no Safra: Chuchu em cubinhos/
  end

  test "explicar uma diferença com nota e depois remover" do
    upload("programacao.ods")
    product = ActsAsTenant.with_tenant(company) { Product.find_by!(code: "cenoura_palitos") }
    params = { kind: "schedule", section: "Bom Pastor", date: "2026-10-12", item: product.code, planilha: "3.0", sistema: "2.0",
               note: "Cliente reduziu por telefone", week: "2026-10-12" }
    post comparison_notes_path, params: params
    assert_redirected_to conference_sheets_path(week: "2026-10-12", anchor: "dia-schedule-2026-10-12")
    follow_redirect!
    assert_select "#dia-schedule-2026-10-12 td.reason", /Explicado pela equipe: Cliente reduziu por telefone \(Escritório Safra/

    note = ActsAsTenant.with_tenant(company) { ComparisonNote.last }
    delete comparison_note_path(note, week: "2026-10-12")
    follow_redirect!
    assert_select ".flash", /Nota removida/
    assert_select "#dia-schedule-2026-10-12 td.reason", text: /Explicado pela equipe/, count: 0
  end

  test "nota vazia volta com o erro" do
    post comparison_notes_path, params: { kind: "schedule", section: "Bom Pastor", date: "2026-10-12", item: "x", note: " ", week: "2026-10-12" }
    follow_redirect!
    assert_select ".flash", /Nota/
  end

  test "o PDF da semana sai com o placar" do
    get conference_sheets_path(week: "2026-10-12", format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end

  test "ligar o cliente da programação" do
    upload("programacao.ods")
    ActsAsTenant.with_tenant(company) { SheetAlias.where(target: "customer").delete_all }
    get conference_sheets_path(week: "2026-10-12")
    assert_select "#nomes", /CENTRAL/
    customer = ActsAsTenant.with_tenant(company) { Customer.find_by!(code: "hnorte") }
    post sheet_aliases_path, params: { target: "customer", label: "CENTRAL", record_id: customer.id, week: "2026-10-12" }
    follow_redirect!
    assert_select ".flash", /"CENTRAL" agora é Hospital Horizonte Norte/
  end

  test "produção não importa planilhas nem liga nomes" do
    sign_in_as(user_for(:production))
    upload("planilha_producao.ods")
    assert_redirected_to production_path
    post sheet_aliases_path, params: { target: "product", label: "X", record_id: "ignore" }
    assert_redirected_to production_path
    post comparison_notes_path, params: { kind: "schedule", section: "Bom Pastor", date: "2026-10-12", item: "x", note: "x" }
    assert_redirected_to production_path
  end
end
