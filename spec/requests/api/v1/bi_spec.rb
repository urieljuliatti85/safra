require "swagger_helper"

RSpec.describe "API v1: tabelas para BI", type: :request do
  let(:Authorization) { "Bearer #{issue_token}" }
  let(:from) { "2026-10-12" }
  let(:to) { "2026-10-18" }

  {
    "schedule" => [ "Programação (uma linha por item entregue)", "delivery_date" ],
    "production" => [ "Produção (uma linha por produto, cliente e entrega)", "production_date" ],
    "purchases" => [ "Compras (uma linha por dia de compra e matéria-prima)", "purchase_date" ],
    "losses" => [ "Perdas (kg processado, kg in natura e perda por produto e dia)", "production_date" ]
  }.each do |name, (title, date_column)|
    path "/api/v1/bi/#{name}" do
      get title do
        tags "BI"
        description "Tabela plana para Metabase, Power BI e Looker Studio, calculada pelo sistema. Padrão: de segunda-feira desta semana até 14 dias. " \
                    "No máximo 92 dias por chamada. Acrescente `.csv` à URL para receber CSV (UTF-8, ponto decimal). Perda = kg in natura − kg processado."
        produces "application/json"
        security [ bearerAuth: [] ]
        parameter name: :Authorization, in: :header, type: :string, required: true
        parameter name: :from, in: :query, type: :string, format: :date, required: false, description: "Primeiro dia (AAAA-MM-DD)"
        parameter name: :to, in: :query, type: :string, format: :date, required: false, description: "Último dia (AAAA-MM-DD)"

        response "200", "linhas do período" do
          schema "$ref" => "#/components/schemas/BiTable"

          run_test! do |response|
            body = JSON.parse(response.body)
            expect(body).to include("from" => from, "to" => to)
            expect(body["rows"]).not_to be_empty
            expect(body["rows"].first.keys).to include(date_column)
            expect(body["rows"].map { |row| row[date_column] }).to all(be_between(from, to))
          end
        end

        response "400", "período inválido" do
          schema "$ref" => "#/components/schemas/Error"
          let(:to) { "2026-10-01" }

          run_test!
        end

        it_requires_token
      end
    end

    path "/api/v1/bi/#{name}.csv" do
      get "#{title}, em CSV" do
        tags "BI"
        description "Mesma tabela em CSV, para carregar direto em planilhas e ferramentas de BI. Envie a chave no cabeçalho `Authorization`."
        produces "text/csv"
        security [ bearerAuth: [] ]
        parameter name: :Authorization, in: :header, type: :string, required: true
        parameter name: :from, in: :query, type: :string, format: :date, required: false
        parameter name: :to, in: :query, type: :string, format: :date, required: false

        response "200", "CSV com cabeçalho" do
          run_test! do |response|
            lines = response.body.delete_prefix("﻿").lines
            expect(response.media_type).to eq("text/csv")
            expect(lines.first.chomp.split(",")).to include(date_column)
            expect(lines.size).to be > 1
          end
        end
      end
    end
  end

  it "perda é kg in natura menos kg processado" do
    get "/api/v1/bi/losses", params: { from: "2026-10-13", to: "2026-10-13" }, headers: { "Authorization" => send(:Authorization) }
    row = JSON.parse(response.body)["rows"].first
    expect(row["loss_kg"]).to be_within(0.001).of(row["raw_kg"] - row["processed_kg"])
    expect(row["loss_pct"]).to be_within(0.1).of(row["loss_kg"] / row["raw_kg"] * 100)
  end

  it "recusa período maior que 92 dias" do
    get "/api/v1/bi/production", params: { from: "2026-01-01", to: "2026-12-31" }, headers: { "Authorization" => send(:Authorization) }
    expect(response).to have_http_status(:bad_request)
  end

  it "só mostra a empresa da chave" do
    other_company
    get "/api/v1/bi/schedule", params: { from: from, to: to }, headers: { "Authorization" => "Bearer #{issue_token(company: other_company)}" }
    expect(JSON.parse(response.body)["rows"]).to eq([])
  end
end
