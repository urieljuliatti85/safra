require "test_helper"

class AuditableTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @admin = user_for(:admin)
    Current.session = @admin.sessions.create!
    Current.request_id = "req-1"
    Current.ip_address = "10.0.0.1"
  end

  teardown do
    Current.reset
    ActsAsTenant.current_tenant = nil
  end

  def last_log = AuditLog.newest_first.first

  test "criar registra quem, o quê e os campos" do
    rm = RawMaterial.create!(name: "Jabuticaba", code: "jabuticaba", purchase_package: "kg", multiply_factor: "1,4")
    log = last_log
    assert_equal [ "create", "RawMaterial", rm.id, "Jabuticaba" ], [ log.action, log.auditable_type, log.auditable_id, log.auditable_label ]
    assert_equal [ @admin.id, "Admin Safra", "req-1", "10.0.0.1" ], [ log.user_id, log.user_name, log.request_id, log.ip_address ]
    assert_equal [ nil, "1,4" ], log.details["Fator"]
    assert_equal [ nil, "Jabuticaba" ], log.details["Nome"]
  end

  test "alterar registra só o que mudou, com antes e depois legíveis" do
    cenoura = RawMaterial.find_by!(code: "cenoura")
    cenoura.update!(multiply_factor: "1,4", supplier: Supplier.find_by!(name: "Fornecedor H"))
    details = last_log.details
    assert_equal [ "update", "Cenoura" ], [ last_log.action, last_log.auditable_label ]
    assert_equal [ "1,35", "1,4" ], details["Fator"]
    assert_equal [ "Fornecedor B", "Fornecedor H" ], details["Fornecedor"]
    assert_equal [ "Fator", "Fornecedor" ].sort, details.keys.sort
  end

  test "alteração sem mudança de valor não registra" do
    cenoura = RawMaterial.find_by!(code: "cenoura")
    assert_no_difference -> { AuditLog.count } do
      cenoura.update!(multiply_factor: "1,35")
      cenoura.touch
    end
  end

  test "excluir guarda como o registro era" do
    rm = RawMaterial.create!(name: "Temporária", code: "temporaria", purchase_package: "cx", kg_per_package: 20)
    rm.destroy!
    log = last_log
    assert_equal [ "destroy", "Temporária" ], [ log.action, log.auditable_label ]
    assert_equal [ "20", nil ], log.details["Kg por embalagem"]
  end

  test "sem usuário logado (seed, console) não registra" do
    Current.reset
    assert_no_difference -> { AuditLog.count } do
      RawMaterial.create!(name: "Invisível", code: "invisivel", purchase_package: "kg")
    end
  end

  test "transação desfeita não deixa registro (como na simulação de regras)" do
    assert_no_difference -> { AuditLog.count } do
      ActiveRecord::Base.transaction do
        Cut.find_by!(code: "cubos").update!(lead_days: 3)
        assert_equal 1, AuditLog.where(auditable_type: "Cut").count
        raise ActiveRecord::Rollback
      end
    end
  end

  test "senha nunca vai para o histórico" do
    @admin.update!(password: "outra-senha-123", password_confirmation: "outra-senha-123")
    log = last_log
    assert_equal [ "[oculta]", "[oculta]" ], log.details["Senha"]
    assert_not_includes log.details.to_json, "outra-senha"
    @admin.update!(password: DEMO_PASSWORD, password_confirmation: DEMO_PASSWORD)
  end

  test "linha de pedido guarda produto, cliente e entrega no nome" do
    hbp = Order.joins(:customer).find_by!(customers: { code: "hbp" })
    line = hbp.lines.create!(product: Product.find_by!(code: "cenoura_ralada"), delivery_date: "2026-10-21", quantity: 4, unit: "kg")
    assert_equal "Cenoura ralada · Bom Pastor · entrega 21/10/2026", last_log.auditable_label
    assert_equal [ nil, "4" ], last_log.details["Quantidade"]
    assert_equal [ nil, "21/10/2026" ], last_log.details["Entrega"]
    assert_nil last_log.details["Pedido"]
    line.update!(quantity: 9)
    assert_equal [ "4", "9" ], last_log.details["Quantidade"]
  end

  test "o histórico não pode ser alterado nem apagado" do
    RawMaterial.create!(name: "X", code: "x", purchase_package: "kg")
    assert_raises(ActiveRecord::ReadOnlyRecord) { last_log.update!(user_name: "outro") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { last_log.destroy }
  end
end
