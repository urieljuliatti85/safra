ENV["RAILS_ENV"] ||= "test"
require "spec_helper"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

Dir[Rails.root.join("spec/support/**/*.rb")].each { |file| require file }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Como na suíte Minitest: os seeds (cadastros e pedidos de 12/10/2026) são carregados uma vez, fora das transações.
  config.before(:suite) do
    original_stdout = $stdout
    $stdout = StringIO.new
    Rails.application.load_seed
  ensure
    $stdout = original_stdout
  end
end
