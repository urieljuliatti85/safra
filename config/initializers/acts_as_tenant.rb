ActsAsTenant.configure do |config|
  # Qualquer consulta a um model com tenant sem Company definida levanta erro.
  config.require_tenant = true
end
