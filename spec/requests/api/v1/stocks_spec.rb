require "swagger_helper"

RSpec.describe "API v1: estoque da câmara fria", type: :request do
  path "/api/v1/stock" do
    get "Contagem de estoque de um dia" do
      tags "Estoque"
      description "Contagens do dia e a última contagem anterior de cada matéria-prima."
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :date, in: :query, type: :string, format: :date, required: false, description: "Padrão: hoje"

      let(:Authorization) { "Bearer #{issue_token}" }
      let(:date) { "2026-10-13" }

      before do
        ActsAsTenant.with_tenant(modelo) do
          StockCount.create!(company: modelo, raw_material: RawMaterial.find_by!(code: "cenoura"), date: "2026-10-12", kg: 40)
          StockCount.create!(company: modelo, raw_material: RawMaterial.find_by!(code: "batata"), date: "2026-10-13", kg: 12.5)
        end
      end

      response "200", "contagens" do
        schema "$ref" => "#/components/schemas/Stock"

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["counts"]).to eq([ { "raw_material" => "batata", "kg" => 12.5 } ])
          expect(body["previous"]).to eq([ { "raw_material" => "cenoura", "kg" => 40.0, "date" => "2026-10-12" } ])
        end
      end

      it_requires_token
    end

    put "Grava a contagem de estoque de um dia" do
      tags "Estoque"
      description "kg vazio ou nulo apaga a contagem (não contado); 0 é câmara vazia. Se uma contagem é inválida, nada é gravado. A compra seguinte abate o que está contado."
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: { "$ref" => "#/components/schemas/StockUpdate" }

      let(:Authorization) { "Bearer #{issue_token(scope: 'write')}" }
      let(:body) { { date: "2026-10-13", counts: [ { raw_material: "cenoura", kg: "12,5" }, { raw_material: "batata", kg: 0 } ] } }

      response "200", "contagem gravada" do
        schema type: :object, properties: { date: { type: :string, format: :date }, changed: { type: :integer } }

        run_test! do |response|
          expect(JSON.parse(response.body)).to eq("date" => "2026-10-13", "changed" => 2)
          expect(in_company { StockCount.find_by!(raw_material: RawMaterial.find_by!(code: "cenoura"), date: "2026-10-13").kg }).to eq(12.5)
          expect(in_company { AuditLog.where(auditable_type: "StockCount").last.user_name }).to eq("API: Spec")
        end
      end

      response "200", "kg nulo apaga a contagem" do
        schema type: :object, properties: { date: { type: :string }, changed: { type: :integer } }
        let(:body) { { date: "2026-10-13", counts: [ { raw_material: "cenoura", kg: nil } ] } }

        before do
          ActsAsTenant.with_tenant(modelo) { StockCount.create!(company: modelo, raw_material: RawMaterial.find_by!(code: "cenoura"), date: "2026-10-13", kg: 9) }
        end

        run_test! do |response|
          expect(JSON.parse(response.body)["changed"]).to eq(1)
          expect(in_company { StockCount.where(date: "2026-10-13").count }).to eq(0)
        end
      end

      response "422", "contagem inválida não grava nada" do
        schema "$ref" => "#/components/schemas/Error"
        let(:body) { { date: "2026-10-13", counts: [ { raw_material: "cenoura", kg: "10" }, { raw_material: "batata", kg: "abc" } ] } }

        run_test! do |response|
          expect(JSON.parse(response.body).dig("error", "details")).not_to be_empty
          expect(in_company { StockCount.where(date: "2026-10-13").count }).to eq(0)
        end
      end

      response "422", "matéria-prima inexistente" do
        schema "$ref" => "#/components/schemas/Error"
        let(:body) { { date: "2026-10-13", counts: [ { raw_material: "fantasma", kg: 1 } ] } }

        run_test! { |response| expect(JSON.parse(response.body).dig("error", "details")).to eq([ "fantasma" ]) }
      end

      it_requires_token
      it_requires_write_token
    end
  end
end
