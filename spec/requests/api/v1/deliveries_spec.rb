require "swagger_helper"

RSpec.describe "API v1: entregas para logística", type: :request do
  let(:Authorization) { "Bearer #{issue_token}" }
  let(:date) { "2026-10-14" }

  before do
    in_company do
      Customer.find_by!(code: "hbp").update!(address: "Rua das Flores, 120", district: "Centro", city: "Vitória", state: "es",
                                           postal_code: "29010-000", delivery_from: "06:00", delivery_until: "09:00",
                                           delivery_notes: "Doca 2", latitude: -20.319, longitude: -40.338)
    end
  end

  path "/api/v1/deliveries" do
    get "Entregas de um dia, uma parada por cliente" do
      tags "Logística"
      description "Para roteirizadores e sistemas de logística: endereço, janela de recebimento, instruções e carga de cada cliente com entrega no dia. " \
                  "`kg_total` soma só o que é pedido em kg; as outras unidades vêm em `other_units`. `missing_address` lista quem entrega e não tem rua e cidade cadastradas. " \
                  "Acrescente `.csv` à URL para uma linha por parada."
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :date, in: :query, type: :string, format: :date, required: false, description: "Dia de entrega. Padrão: hoje"

      response "200", "paradas do dia" do
        schema "$ref" => "#/components/schemas/Deliveries"

        run_test! do |response|
          body = JSON.parse(response.body)
          stop = body["stops"].find { |s| s["code"] == "hbp" }
          expect(stop["address"]).to include("line" => "Rua das Flores, 120", "state" => "ES", "postal_code" => "29010000",
                                             "full" => "Rua das Flores, 120 - Centro, Vitória/ES, CEP 29010-000")
          expect(stop["delivery_window"]).to eq("from" => "06:00", "until" => "09:00")
          expect(stop["kg_total"]).to be > 0
          expect(stop["lines"]).to all(include("product", "quantity", "unit"))
          expect(body["missing_address"]).not_to include("hbp")
          expect(body["missing_address"]).not_to be_empty
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

  path "/api/v1/deliveries.csv" do
    get "Entregas de um dia, em CSV" do
      tags "Logística"
      description "Uma linha por parada, com cabeçalho, para importar em roteirizadores e planilhas."
      produces "text/csv"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :date, in: :query, type: :string, format: :date, required: false

      response "200", "CSV com uma linha por parada" do
        run_test! do |response|
          rows = CSV.parse(response.body.delete_prefix("\uFEFF"), headers: true)
          expect(rows.headers).to include("address", "city", "delivery_from", "kg_total")
          hbp = rows.find { |row| row["customer"] == "hbp" }
          expect(hbp["city"]).to eq("Vitória")
          expect(hbp["delivery_until"]).to eq("09:00")
        end
      end
    end
  end

  it "só mostra a empresa da chave" do
    get "/api/v1/deliveries", params: { date: date }, headers: { "Authorization" => "Bearer #{issue_token(company: other_company)}" }
    expect(JSON.parse(response.body)["stops"]).to eq([])
  end
end
