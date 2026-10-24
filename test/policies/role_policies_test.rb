require "test_helper"

# Matriz papel x ação das policies com regra própria. Usuários em memória: a policy só olha o papel.
class RolePoliciesTest < ActiveSupport::TestCase
  MATRIX = {
    ProductionPolicy => { show: %w[admin office production], publish: %w[admin office], draft: %w[admin office] },
    PushSubscriptionPolicy => { show: %w[admin office production], create: %w[admin office production], destroy: %w[admin office production] },
    TourPolicy => { show: %w[admin office], create: %w[admin office] }
  }.freeze

  MATRIX.each do |policy, actions|
    actions.each do |action, allowed|
      test "#{policy.name} #{action}? libera só #{allowed.join(', ')}" do
        User::ROLES.each do |role|
          expected = allowed.include?(role)
          assert_equal expected, policy.new(User.new(role: role), nil).public_send(:"#{action}?"), "#{role} em #{action}?"
        end
      end
    end
  end

  test "sem usuário, nada é liberado" do
    MATRIX.each do |policy, actions|
      actions.each_key { |action| assert_not policy.new(nil, nil).public_send(:"#{action}?"), "#{policy.name} #{action}?" }
    end
    assert_not CompanyPolicy.new(nil, nil).index?
  end

  test "empresas: só o dono da plataforma, nem o admin da empresa" do
    %i[index new create edit update].each do |action|
      User::ROLES.each do |role|
        assert_not CompanyPolicy.new(User.new(role: role), nil).public_send(:"#{action}?"), "#{role} em #{action}?"
      end
      assert CompanyPolicy.new(User.new(role: "office", platform_admin: true), nil).public_send(:"#{action}?")
    end
  end
end
