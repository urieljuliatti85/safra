require "test_helper"

class ProductTest < ActiveSupport::TestCase
  setup { ActsAsTenant.current_tenant = company }
  teardown { ActsAsTenant.current_tenant = nil }

  test "medida do preparo: a do pedido, senão a do produto, senão a de referência do corte (R1.14, R2.12, D30)" do
    cenoura = Product.find_by!(code: "cenoura_ralada")
    assert_equal "3 mm", cenoura.default_measure
    assert_equal "3 mm", cenoura.measure_for(nil)
    assert_equal "3 mm", cenoura.measure_for(" ")
    assert_equal "5 mm", cenoura.measure_for("5 mm")
    assert_equal "3 a 5 mm", Product.find_by!(code: "beterraba_ralada").measure_for(nil)
    assert_equal "3 mm", cenoura.measure_hint
    assert_equal "3 a 5 mm", Product.find_by!(code: "beterraba_ralada").measure_hint
  end

  test "corte de medida única: a medida fixa do produto, senão a do corte, mesmo com outra no pedido (R2.11, D32)" do
    vagem = Product.find_by!(code: "vagem_palitos")
    assert_equal "40 × 10 mm", vagem.fixed_measure
    assert_equal "40 × 10 mm", vagem.measure_for(nil)
    assert_equal "40 × 10 mm", vagem.measure_for("10 × 10 × 60 mm")
    assert_equal "40 × 10 mm (medida única)", vagem.measure_hint

    cenoura = Product.find_by!(code: "cenoura_palitos")
    assert_nil cenoura.default_measure
    assert_equal "10 × 10 × 60 mm", cenoura.measure_for(nil)
    assert_equal "10 × 10 × 60 mm", cenoura.measure_for("40 × 10 mm")
    assert_equal "10 × 10 × 60 mm (medida única)", cenoura.measure_hint
  end

  test "produto fora de corte de medida única não tem medida fixa" do
    assert_nil Product.find_by!(code: "cenoura_ralada").fixed_measure
  end

  test "medida do produto em branco fica vazia" do
    cenoura = Product.find_by!(code: "cenoura_ralada")
    cenoura.update!(default_measure: "  ")
    assert_nil cenoura.reload.default_measure
    assert_equal "3 a 5 mm", cenoura.measure_for(nil)
  end

  test "a composição guarda a medida dos ralados e picados das misturas (R1.20, D30)" do
    measures = Product.find_by!(code: "salada_roxa").components.includes(:component).to_h { |c| [ c.component.code, c.measure ] }
    assert_equal({ "repolho_roxo_picado" => "3 mm", "cenoura_ralada" => "3 mm", "repolho_picado" => "3 mm", "beterraba_ralada" => "3 mm" }, measures)
    assert_equal [ nil ], Product.find_by!(code: "seleta").components.map(&:measure).uniq
  end
end
