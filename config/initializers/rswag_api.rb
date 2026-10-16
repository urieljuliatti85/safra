# Serve o OpenAPI gerado pelos specs (bin/rails rswag:specs:swaggerize) em /api-docs/v1/swagger.yaml.
Rswag::Api.configure do |c|
  c.openapi_root = Rails.root.join("swagger").to_s
end
