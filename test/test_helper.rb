ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

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
  end
end

# Os seeds são carregados uma vez por execução (fora das transações dos testes) para os testes ficarem rápidos.
ActiveSupport::TestCase.new("seeds").load_seeds
