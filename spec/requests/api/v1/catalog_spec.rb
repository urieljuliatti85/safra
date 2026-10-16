require "swagger_helper"

RSpec.describe "API v1: cadastros", type: :request do
  {
    "customers" => [ "Clientes", "Customer", "hbp" ],
    "suppliers" => [ "Fornecedores", "Supplier", nil ],
    "cuts" => [ "Cortes", "Cut", "cubinhos" ],
    "raw_materials" => [ "Matérias-primas", "RawMaterial", "cenoura" ],
    "products" => [ "Produtos", "Product", "cenoura_cubinhos" ]
  }.each do |resource, (title, schema_name, sample_code)|
    path "/api/v1/#{resource}" do
      get "Lista: #{title.downcase}" do
        tags "Cadastros"
        produces "application/json"
        security [ bearerAuth: [] ]
        parameter name: :Authorization, in: :header, type: :string, required: true, description: "Bearer <chave>"

        response "200", title.downcase do
          schema type: :object, required: %w[data], properties: { data: { type: :array, items: { "$ref" => "#/components/schemas/#{schema_name}" } } }
          let(:Authorization) { "Bearer #{issue_token}" }

          run_test! do |response|
            data = JSON.parse(response.body)["data"]
            expect(data).not_to be_empty
            expect(data.map { |row| row["code"] }).to include(sample_code) if sample_code
          end
        end

        it_requires_token
      end
    end
  end

  describe "isolamento por empresa" do
    path "/api/v1/customers" do
      get "Lista: clientes" do
        security [ bearerAuth: [] ]
        parameter name: :Authorization, in: :header, type: :string, required: true

        response "200", "só enxerga a própria empresa" do
          let(:Authorization) { "Bearer #{issue_token(company: other_company)}" }

          run_test! do |response|
            expect(JSON.parse(response.body)["data"].map { |row| row["code"] }).to eq([ "x1" ])
          end
        end
      end
    end
  end

  describe "chave inutilizável" do
    path "/api/v1/customers" do
      get "Lista: clientes" do
        security [ bearerAuth: [] ]
        parameter name: :Authorization, in: :header, type: :string, required: true

        response "401", "chave revogada" do
          let(:Authorization) do
            token, plain = ApiToken.issue!(company: modelo, name: "Velha", scope: "read")
            token.revoke!
            "Bearer #{plain}"
          end

          run_test!
        end

        response "401", "empresa suspensa" do
          let(:Authorization) do
            company = Company.create!(name: "Suspensa", active: false)
            "Bearer #{issue_token(company: company)}"
          end

          run_test!
        end

        response "401", "sem cabeçalho de autorização" do
          let(:Authorization) { nil }

          run_test!
        end
      end
    end
  end
end
