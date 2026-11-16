require "test_helper"

class CutTest < ActiveSupport::TestCase
  setup { ActsAsTenant.current_tenant = company }
  teardown { ActsAsTenant.current_tenant = nil }

  test "nome repetido com outra caixa é recusado pelo modelo e também pelo banco" do
    duplicate = Cut.new(code: "cubos_2", name: "CUBOS", sector: "manual", lead_days: 1)
    assert_not duplicate.valid?
    assert duplicate.errors.added?(:name, :taken, value: "CUBOS")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "medida do preparo: a do pedido, senão a de referência (R1.14)" do
    cubinhos = Cut.find_by!(code: "cubinhos")
    assert_equal "10 × 10 × 10 mm", cubinhos.measure_for(nil)
    assert_equal "10 × 10 × 10 mm", cubinhos.measure_for("  ")
    assert_equal "12 × 12 mm", cubinhos.measure_for("12 × 12 mm")
  end

  test "palito tem medida única 40 × 10 mm, mesmo com outra medida no pedido (R2.11, D26)" do
    palitos = Cut.find_by!(code: "palitos")
    assert palitos.single_measure?
    assert_equal "40 × 10 mm", palitos.reference_measure
    assert_equal "40 × 10 mm", palitos.measure_for("10 × 10 × 60 mm")
    assert_equal "40 × 10 mm", palitos.measure_for(nil)
    assert_equal "40 × 10 mm (medida única)", palitos.measure_hint
    assert_equal "10 × 10 × 10 mm", Cut.find_by!(code: "cubinhos").measure_hint
  end

  test "medida única pede a medida de referência" do
    cut = Cut.new(code: "juliana", name: "Juliana", sector: "manual", lead_days: 1, single_measure: true)
    assert_not cut.valid?
    assert_includes cut.errors[:reference_measure], "é obrigatória quando a medida é única"
    cut.reference_measure = "2 × 2 × 40 mm"
    assert cut.valid?
  end
end
