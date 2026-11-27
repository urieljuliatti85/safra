require "test_helper"

# Cadastros › Dias de compra (esteira simplificada, passo 3): dias da semana, segunda e quinta por padrão.
class PurchaseCalendarTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(user_for(:office)) }

  test "a empresa nova compra na segunda e na quinta" do
    assert_equal [ 1, 4 ], Company.create!(name: "Nova").purchase_weekdays
  end

  test "a tela marca os dias e salva a escolha" do
    get purchase_calendar_path
    assert_response :success
    assert_select "nav[aria-label=Cadastros] a[aria-current=true]", "Dias de compra"
    assert_select "input#weekday_2[checked]"
    patch purchase_calendar_path, params: { weekdays: %w[1 4] }
    assert_redirected_to purchase_calendar_path
    assert_equal [ 1, 4 ], company.reload.purchase_weekdays
  end

  test "sem nenhum dia marcado nada muda" do
    patch purchase_calendar_path, params: { weekdays: [] }
    assert_redirected_to purchase_calendar_path
    follow_redirect!
    assert_match "Marque pelo menos um dia de compra", response.body
    assert_equal [ 2, 4 ], company.reload.purchase_weekdays
  end

  test "a compra segue os dias cadastrados" do
    patch purchase_calendar_path, params: { weekdays: %w[1 4] }
    dates = ActsAsTenant.with_tenant(company) { PurchasePlanner.new(company: company).call.purchases.keys }
    assert dates.all? { |date| date.monday? || date.thursday? }
    assert_includes dates, Date.new(2026, 10, 12)
  end

  test "produção não abre os dias de compra" do
    sign_in_as(user_for(:production))
    get purchase_calendar_path
    assert_redirected_to production_path
  end
end
