require "test_helper"

# O database.yml de produção deriva os bancos do Solid Cache, Queue e Cable da DATABASE_URL. O CI define essa
# variável sem o nome do banco (postgres://usuário:senha@host:5432): a derivação não pode quebrar.
class DatabaseConfigTest < ActiveSupport::TestCase
  PRODUCTION_DATABASES = { "cache" => "safra_production_cache", "queue" => "safra_production_queue", "cable" => "safra_production_cable" }.freeze

  def production_config(database_url)
    original = ENV["DATABASE_URL"]
    database_url ? ENV["DATABASE_URL"] = database_url : ENV.delete("DATABASE_URL")
    yaml = ERB.new(Rails.root.join("config/database.yml").read).result
    YAML.safe_load(yaml, aliases: true).fetch("production")
  ensure
    original ? ENV["DATABASE_URL"] = original : ENV.delete("DATABASE_URL")
  end

  test "URL com banco (Railway): troca só o nome do banco dos três bancos do Solid" do
    config = production_config("postgresql://postgres:segredo@db.railway.internal:5432/railway")
    assert_equal "postgresql://postgres:segredo@db.railway.internal:5432/railway", config["primary"]["url"]
    PRODUCTION_DATABASES.each do |name, database|
      assert_equal "postgresql://postgres:segredo@db.railway.internal:5432/#{database}", config[name]["url"]
    end
  end

  test "URL sem banco (formato do CI) não quebra e ganha o nome do banco" do
    config = production_config("postgres://postgres:postgres@localhost:5432")
    PRODUCTION_DATABASES.each do |name, database|
      assert_equal "postgres://postgres:postgres@localhost:5432/#{database}", config[name]["url"]
    end
  end

  test "mantém parâmetros e a senha com caracteres especiais" do
    config = production_config("postgresql://u:p%40ss@h:5432/railway?sslmode=require")
    assert_equal "postgresql://u:p%40ss@h:5432/safra_production_queue?sslmode=require", config["queue"]["url"]
  end

  test "sem DATABASE_URL (Kamal) não define URL e usa os bancos nomeados" do
    config = production_config(nil)
    PRODUCTION_DATABASES.each do |name, database|
      assert_nil config[name]["url"]
      assert_equal database, config[name]["database"]
    end
  end
end
