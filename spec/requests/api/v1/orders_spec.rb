require "swagger_helper"

RSpec.describe "API v1: pedidos", type: :request do
  path "/api/v1/orders" do
    get "Lê o pedido de um cliente em uma semana" do
      tags "Pedidos"
      description "Devolve as linhas do pedido (produto, unidade, data de entrega e quantidade). Semana sem pedido volta com `lines` vazio."
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer, in: :query, type: :string, required: true, description: "Código do cliente"
      parameter name: :week, in: :query, type: :string, format: :date, required: true, description: "Segunda-feira da semana (AAAA-MM-DD)"

      let(:Authorization) { "Bearer #{issue_token}" }
      let(:customer) { "hbp" }
      let(:week) { "2026-10-12" }

      response "200", "pedido da semana" do
        schema "$ref" => "#/components/schemas/Order"

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body).to include("customer" => "hbp", "week_start" => "2026-10-12")
          expect(body["lines"]).not_to be_empty
          expect(body["lines"].first.keys).to include("product", "unit", "date", "quantity")
        end
      end

      response "200", "semana sem pedido" do
        schema "$ref" => "#/components/schemas/Order"
        let(:week) { "2030-01-07" }

        run_test! do |response|
          expect(JSON.parse(response.body)["lines"]).to eq([])
          expect(in_company { Order.where(week_start: "2030-01-07").count }).to eq(0)
        end
      end

      response "404", "cliente inexistente" do
        schema "$ref" => "#/components/schemas/Error"
        let(:customer) { "nao-existe" }

        run_test!
      end

      response "400", "semana que não começa na segunda-feira" do
        schema "$ref" => "#/components/schemas/Error"
        let(:week) { "2026-10-14" }

        run_test! { |response| expect(JSON.parse(response.body).dig("error", "code")).to eq("bad_request") }
      end

      it_requires_token
    end

    put "Grava linhas do pedido de um cliente em uma semana" do
      tags "Pedidos"
      description <<~TEXT
        Cria o pedido da semana se não existir e grava as linhas enviadas, como na grade de pedidos: quantidade 0 ou vazia
        apaga a linha; o que não vem no corpo não muda. Se uma linha é inválida, nada é gravado. A resposta traz o pedido
        atualizado, os dias de entrega que mudaram e os dias com produção já enviada que ficou diferente (`stale_plans`).
      TEXT
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: { "$ref" => "#/components/schemas/OrderUpdate" }

      let(:Authorization) { "Bearer #{issue_token(scope: 'write')}" }
      let(:body) { { customer: "hnorte", week: "2026-10-12", lines: [ { product: "cenoura_ralada", date: "2026-10-14", quantity: "7,5" } ], late_confirmed: true } }

      response "200", "pedido gravado" do
        schema "$ref" => "#/components/schemas/Order"

        run_test! do |response|
          result = JSON.parse(response.body)
          expect(result["changed_dates"]).to eq([ "2026-10-14" ])
          expect(result["lines"]).to include(a_hash_including("product" => "cenoura_ralada", "date" => "2026-10-14", "quantity" => 7.5))
          line = in_company { OrderLine.joins(:product, order: :customer).find_by!(products: { code: "cenoura_ralada" }, customers: { code: "hnorte" }, delivery_date: "2026-10-14") }
          expect(line.quantity).to eq(7.5)
          log = in_company { AuditLog.where(auditable_type: "OrderLine").order(:id).last }
          expect(log.user_name).to eq("API: Spec")
          expect(log.user).to be_nil
        end
      end

      response "200", "quantidade zero apaga a linha" do
        schema "$ref" => "#/components/schemas/Order"
        let(:body) { { customer: "hnorte", week: "2026-10-12", lines: [ { product: "cenoura_ralada", date: "2026-10-14", quantity: 0 } ], late_confirmed: true } }

        run_test! do |response|
          expect(JSON.parse(response.body)["lines"].none? { |l| l["product"] == "cenoura_ralada" && l["date"] == "2026-10-14" }).to be(true)
        end
      end

      response "200", "cria o pedido de uma semana nova" do
        schema "$ref" => "#/components/schemas/Order"
        let(:body) { { customer: "hbp", week: "2030-01-07", lines: [ { product: "cenoura_ralada", date: "2030-01-08", quantity: 3 } ] } }

        run_test! do
          expect(in_company { Order.find_by!(week_start: "2030-01-07").lines.count }).to eq(1)
        end
      end

      response "422", "linha inválida não grava nada" do
        schema "$ref" => "#/components/schemas/Error"
        let(:body) do
          { customer: "hnorte", week: "2026-10-12",
            lines: [ { product: "cenoura_ralada", date: "2026-10-14", quantity: "5 + 2" }, { product: "fantasma", date: "2026-10-14", quantity: 1 },
                     { product: "cenoura_ralada", date: "2026-12-01", quantity: 1 } ] }
        end

        run_test! do |response|
          details = JSON.parse(response.body).dig("error", "details")
          expect(details.size).to be >= 2
          expect(details.join(" ")).to match(/fantasma/).and match(/fora da semana/)
          expect(in_company { OrderLine.where(delivery_date: "2026-12-01").count }).to eq(0)
        end
      end

      response "400", "sem linhas" do
        schema "$ref" => "#/components/schemas/Error"
        let(:body) { { customer: "hnorte", week: "2026-10-12" } }

        run_test!
      end

      it_requires_token
      it_requires_write_token
    end
  end
end
