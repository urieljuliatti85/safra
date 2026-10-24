require "test_helper"

# Textos que a tela mostra: números em pt-BR, plurais, antecedência e linhas do histórico.
class ApplicationHelperTest < ActionView::TestCase
  Change = Struct.new(:kind, :before, :after, :unit)
  Log = Struct.new(:action, :auditable_type, :auditable_label)
  Event = Struct.new(:logs)

  test "kg_text usa ponto no milhar, vírgula na decimal e tira o zero inútil" do
    assert_equal "3.919,4", kg_text(3919.4)
    assert_equal "198", kg_text(198.0)
    assert_equal "0,5", kg_text(0.46)
  end

  test "plural escolhe a forma pelo número" do
    assert_equal "1 item", plural(1, "item", "itens")
    assert_equal "0 itens", plural(0, "item", "itens")
    assert_equal "3 itens", plural(3, "item", "itens")
  end

  test "lead_options fala a antecedência em dias, do dia da entrega a 5 dias antes" do
    assert_equal [ "No dia da entrega", 0 ], lead_options.first
    assert_equal [ "1 dia antes", 1 ], lead_options.second
    assert_equal [ "5 dias antes", 5 ], lead_options.last
    assert_equal 6, lead_options.size
  end

  test "change_text descreve item novo, removido e alterado" do
    assert_equal "novo: 12,5 kg", change_text(Change.new(:added, nil, 12.5, "kg"))
    assert_equal "removido (era 3 cx)", change_text(Change.new(:removed, 3, nil, "cx"))
    assert_equal "10 → 11,5 kg", change_text(Change.new(:changed, 10, 11.5, "kg"))
  end

  test "audit_change_text mostra um lado só na criação e na exclusão" do
    assert_equal "Fator: 1,35 → 1,4", audit_change_text("Fator", "1,35", "1,4")
    assert_equal "Nome: Cenoura", audit_change_text("Nome", nil, "Cenoura")
    assert_equal "Nome: era Cenoura", audit_change_text("Nome", "Cenoura", nil)
    assert_equal "Nome", audit_change_text("Nome", nil, nil)
  end

  test "audit_headline: uma mudança diz qual registro, várias dizem quantas" do
    one = Event.new([ Log.new("update", "RawMaterial", "Cenoura") ])
    assert_equal "alterou matéria-prima: Cenoura", audit_headline(one)

    many = Event.new([ Log.new("update", "Product", "A"), Log.new("update", "Product", "B"), Log.new("create", "Customer", "C") ])
    assert_equal "alterou 2 produtos e criou 1 cliente", audit_headline(many)
  end

  test "audit_log_headline de acesso não cita registro" do
    assert_equal "entrou no sistema", audit_log_headline(Log.new("login", nil, nil))
    assert_equal "tentou entrar sem sucesso", audit_log_headline(Log.new("login_failed", nil, nil))
  end
end
