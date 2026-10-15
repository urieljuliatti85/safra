ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
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
  end
end

# Os seeds são carregados uma vez por execução (fora das transações dos testes) para os testes ficarem rápidos.
ActiveSupport::TestCase.new("seeds").load_seeds
