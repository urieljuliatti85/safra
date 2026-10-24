require "test_helper"

# Ordem, valores e destaque das linhas de Sistema x planilhas.
class ConferencesHelperTest < ActionView::TestCase
  include ApplicationHelper

  Row = Struct.new(:label, :status, :unit, :planilha, :sistema, :planilha_text, :ok, :explained, :scored, keyword_init: true) do
    def ok? = ok
    def explained? = explained
    def scored? = scored
  end

  def row(**attrs)
    Row.new(label: "Cenoura cubinhos", status: :different, unit: "kg", ok: false, explained: false, scored: true, **attrs)
  end

  test "comparison_sorted põe primeiro a diferença sem motivo, depois a explicada, por último o que bate" do
    ok = row(label: "A", status: :ok, ok: true)
    explained = row(label: "B", explained: true)
    open = row(label: "C")
    assert_equal [ open, explained, ok ], comparison_sorted([ ok, explained, open ])
  end

  test "comparison_value formata a quantidade com a unidade e usa traço sem valor" do
    assert_equal "12,5 kg", comparison_value(row(sistema: 12.5), :sistema)
    assert_equal "-", comparison_value(row(sistema: nil), :sistema)
    assert_equal "2 cx de 20", comparison_value(row(planilha: 40, planilha_text: "2 cx de 20"), :planilha)
  end

  test "comparison_row_class destaca o que difere sem explicação e o que não foi reconhecido" do
    assert_equal "is-ok", comparison_row_class(row(ok: true))
    assert_equal "is-changed", comparison_row_class(row)
    assert_equal "is-changed", comparison_row_class(row(status: :unmatched, scored: false))
    assert_nil comparison_row_class(row(explained: true))
  end

  test "comparison_notable? só para diferenças reconhecidas" do
    assert comparison_notable?(row)
    assert_not comparison_notable?(row(ok: true))
    assert_not comparison_notable?(row(status: :unmatched))
  end

  test "comparison_week_text vai de segunda a domingo" do
    assert_equal "12/10 a 18/10", comparison_week_text(Date.new(2026, 10, 12))
  end
end
