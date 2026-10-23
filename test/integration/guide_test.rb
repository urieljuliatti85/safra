require "test_helper"

class GuideTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(user_for(:office)) }

  test "como funciona explica o que acontece depois da importação" do
    get guide_path
    assert_response :success
    assert_select "h2#guide-after", "Depois da importação"
    %w[desfazer programacao producao compras conferencia regras cadastros].each do |id|
      assert_select "nav[aria-label='Assuntos'] a[href='##{id}']"
      assert_select "section##{id} h3"
    end
    assert_select "section#desfazer li", /pill vermelha Desfazer/
    assert_select "section#desfazer li", /Restaurar esta versão/
    assert_select "section#compras li", /fator de perda/
    assert_select "section#cadastros a[href='#{raw_materials_path}']", "Abrir Cadastros"
  end
end
