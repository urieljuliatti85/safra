ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/push_test_helper"

module ActiveSupport
  class TestCase
    include PushTestHelper
    # Os testes dependem dos seeds carregados no banco; rodam em série para evitar bancos paralelos.

    # Recarrega db/seeds_data (cadastros e pedidos de 12/10/2026). O seed é idempotente.
    def load_seeds
      original_stdout = $stdout
      $stdout = StringIO.new
      Rails.application.load_seed
    ensure
      $stdout = original_stdout
    end

    def company
      @company ||= Company.find_by!(name: "Hortifruti Modelo")
    end

    # Usuários de cada papel criados pelo seed de teste (senha em DEMO_PASSWORD).
    DEMO_PASSWORD = "safra-dev-123".freeze
    DEMO_EMAILS = { admin: "admin@safra.local", office: "escritorio@safra.local", production: "producao@safra.local" }.freeze

    def user_for(role)
      User.find_by!(email_address: DEMO_EMAILS.fetch(role))
    end

    # "Como funciona" e tour estão escondidos por padrão (config.x.guides_enabled); os testes deles ligam a chave.
    def self.with_guides
      setup { @guides_before = Rails.configuration.x.guides_enabled; Rails.configuration.x.guides_enabled = true }
      teardown { Rails.configuration.x.guides_enabled = @guides_before }
    end
  end
end

# Os seeds são carregados uma vez por execução (fora das transações dos testes) para os testes ficarem rápidos.
ActiveSupport::TestCase.new("seeds").load_seeds
