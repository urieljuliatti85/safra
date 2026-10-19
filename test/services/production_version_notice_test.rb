require "test_helper"

class ProductionVersionNoticeTest < ActiveSupport::TestCase
  setup do
    ActsAsTenant.current_tenant = company
    @date = Date.new(2026, 10, 13)
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def publish
    PlanPublisher.production(company: company, result: ProductionPlanner.new(company: company, date: @date).call)
  end

  def change_cenoura_ralada(by)
    OrderLine.joins(:product).find_by!(products: { code: "cenoura_ralada" }, delivery_date: @date).increment!(:quantity, by)
  end

  test "primeiro envio avisa todos os setores que têm itens, com o nome do setor" do
    notice = ProductionVersionNotice.new(publish)
    assert_includes notice.sectors, "ralpic"
    assert_includes notice.sectors, "aprontes"

    message = notice.message_for(%w[ralpic])
    assert_equal "Produção Ter 13/10: v1 enviada", message.title
    assert_equal "Primeiro envio: Ralados, picados e rodelas.", message.options[:body]
    assert_equal "/production?date=2026-10-13&sector=ralpic", message.options[:data][:path]
  end

  test "a partir da v2 só avisa o setor que mudou, com o que mudou" do
    publish
    change_cenoura_ralada(4)
    notice = ProductionVersionNotice.new(publish)

    assert_equal [ "ralpic" ], notice.sectors
    message = notice.message_for(%w[ralpic palito])
    assert_equal "Produção Ter 13/10: v2 enviada", message.title
    assert_equal "Cenoura ralada: 3 → 7 kg", message.options[:body]
    assert_nil notice.message_for(%w[palito cubinho])
    assert_equal "producao-2026-10-13", message.options[:tag]
  end

  test "quem acompanha vários setores abre o dia inteiro, não um setor só" do
    publish
    change_cenoura_ralada(100)
    notice = ProductionVersionNotice.new(publish)

    assert_equal %w[ralpic aprontes], notice.sectors
    message = notice.message_for(%w[ralpic aprontes])
    assert_equal "/production?date=2026-10-13", message.options[:data][:path]
    assert_match "Aprontes: caixas mudaram", message.options[:body]
    assert_equal "Aprontes: caixas mudaram", notice.message_for(%w[aprontes]).options[:body]
  end

  test "versão igual à anterior não avisa ninguém" do
    publish
    notice = ProductionVersionNotice.new(publish)
    assert_empty notice.sectors
    assert_nil notice.message_for(PushSubscription::SECTORS)
  end
end
