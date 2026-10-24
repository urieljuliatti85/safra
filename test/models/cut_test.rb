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
end
