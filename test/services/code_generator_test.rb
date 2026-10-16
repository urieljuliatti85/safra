require "test_helper"

class CodeGeneratorTest < ActiveSupport::TestCase
  setup { ActsAsTenant.current_tenant = company }
  teardown { ActsAsTenant.current_tenant = nil }

  test "gera o código do nome sem acento nem espaço" do
    assert_equal "pimentao_amarelo_doce", CodeGenerator.call(RawMaterial, "Pimentão Amarelo (doce)")
  end

  test "não repete um código existente" do
    assert_equal "cenoura_2", CodeGenerator.call(RawMaterial, "Cenoura")
  end

  test "aceita prefixo e nome sem letras" do
    assert_equal "in_jabuticaba", CodeGenerator.call(Product, "Jabuticaba", prefix: "in_")
    assert_equal "item", CodeGenerator.call(Product, "???")
  end
end
