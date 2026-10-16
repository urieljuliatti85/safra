require "swagger_helper"

RSpec.describe "API v1: programação, produção e compras", type: :request do
  let(:Authorization) { "Bearer #{issue_token}" }

  path "/api/v1/schedule" do
    get "Programação de entregas de um dia" do
      tags "Planos"
      description "O que cada cliente pediu para entregar no dia e quando cada item é produzido."
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :date, in: :query, type: :string, format: :date, required: false, description: "Padrão: hoje"

      response "200", "programação do dia" do
        schema "$ref" => "#/components/schemas/Schedule"
        let(:date) { "2026-10-14" }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["date"]).to eq("2026-10-14")
          expect(body["customers"]).not_to be_empty
          expect(body["customers"].first["items"].first.keys).to include("product", "quantity", "unit", "production_date")
        end
      end

      response "400", "data inválida" do
        schema "$ref" => "#/components/schemas/Error"
        let(:date) { "14/10/2026" }

        run_test!
      end

      it_requires_token
    end
  end

  path "/api/v1/production" do
    get "Produção de um dia, por produto, com a abertura por cliente e os aprontes" do
      tags "Planos"
      description "Calculada pelo sistema a partir dos pedidos. `sent_version` é a última versão enviada aos setores; `changes_since_sent` mostra o que mudou desde então."
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :date, in: :query, type: :string, format: :date, required: false, description: "Padrão: hoje"

      response "200", "produção do dia" do
        schema "$ref" => "#/components/schemas/Production"
        let(:date) { "2026-10-13" }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["items"]).not_to be_empty
          expect(body["items"].first["breakdown"]).not_to be_empty
          expect(body["sent_version"]).to be_nil
          expect(body["changes_since_sent"]).to eq([])
        end
      end

      response "200", "traz a versão enviada e o que mudou depois" do
        schema "$ref" => "#/components/schemas/Production"
        let(:date) { "2026-10-13" }

        before do
          ActsAsTenant.with_tenant(modelo) do
            result = ProductionPlanner.new(company: modelo, date: Date.new(2026, 10, 13)).call
            PlanPublisher.production(company: modelo, result: result)
            product = Product.find_by!(code: "cenoura_ralada")
            line = OrderLine.joins(:order).find_by!(product: product, delivery_date: "2026-10-13")
            line.update!(quantity: line.quantity + 5)
          end
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["sent_version"]).to include("version" => 1)
          expect(body["changes_since_sent"]).to include(a_hash_including("kind" => "changed"))
        end
      end

      it_requires_token
    end
  end

  path "/api/v1/purchases" do
    get "Compra da CEASA de um dia de compra, por matéria-prima" do
      tags "Planos"
      description "Quantidade a comprar (já abatido o estoque da câmara fria) por matéria-prima. Sem `date`, usa o dia de compra mais recente até hoje."
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :date, in: :query, type: :string, format: :date, required: false, description: "Dia de compra (AAAA-MM-DD)"

      response "200", "compra do dia" do
        schema "$ref" => "#/components/schemas/Purchase"
        let(:date) { in_company { PurchaseDay.order(:date).pick(:date) }.iso8601 }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["date"]).to eq(date)
          expect(body["items"]).to all(include("raw_material", "kg", "net_kg"))
        end
      end

      it_requires_token
    end
  end
end
