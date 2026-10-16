require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "API do Safra",
        version: "v1",
        description: <<~TEXT
          Integração com o Safra, sistema de planejamento de produção e compras. Cada chave de API pertence a uma empresa
          e só enxerga os dados dela. O administrador cria e revoga chaves em "Chaves de API", no menu da conta.

          **Autenticação:** envie `Authorization: Bearer <chave>`. Chaves de leitura consultam; chaves de escrita também gravam
          pedidos e contagens de estoque. Erros vêm como `{ "error": { "code", "message", "details" } }`.

          **Formatos:** datas em AAAA-MM-DD; quantidades como número decimal (kg, un, cx ou mç, conforme a unidade); a semana de
          pedido começa na segunda-feira e cobre 8 dias (segunda a segunda). O limite é de 300 requisições por minuto por chave.
        TEXT
      },
      servers: [ { url: "/", description: "Esta instalação" } ],
      components: {
        securitySchemes: { bearerAuth: { type: :http, scheme: :bearer, description: "Chave de API da empresa (safra_...)" } },
        schemas: {
          Error: {
            type: :object, required: %w[error],
            properties: { error: { type: :object, required: %w[code message],
                                   properties: { code: { type: :string, example: "unauthorized" }, message: { type: :string },
                                                 details: { type: :array, items: { type: :string } } } } }
          },
          Customer: { type: :object, required: %w[code name short_name],
                      properties: { code: { type: :string, example: "hbp" }, name: { type: :string, example: "Hospital Bom Pastor" }, short_name: { type: :string } } },
          Supplier: { type: :object, required: %w[id name], properties: { id: { type: :integer }, name: { type: :string } } },
          Cut: { type: :object, required: %w[code name sector sector_name lead_days],
                 properties: { code: { type: :string, example: "cubinhos" }, name: { type: :string }, sector: { type: :string }, sector_name: { type: :string }, lead_days: { type: :integer } } },
          RawMaterial: { type: :object, required: %w[code name],
                         properties: { code: { type: :string, example: "cenoura" }, name: { type: :string }, supplier: { type: :string, nullable: true },
                                       multiply_factor: { type: :number, nullable: true, description: "kg in natura por kg processado" },
                                       kg_per_package: { type: :number, nullable: true }, kg_per_peeled_box: { type: :number, nullable: true },
                                       purchase_package: { type: :string, example: "sc" } } },
          Product: { type: :object, required: %w[code name group unit raw_material],
                     properties: { code: { type: :string, example: "cenoura_cubinhos" }, name: { type: :string }, group: { type: :string, enum: %w[processed raw fruit] },
                                   unit: { type: :string, enum: %w[kg un cx mç] }, raw_material: { type: :string }, cut: { type: :string, nullable: true }, sector: { type: :string, nullable: true } } },
          OrderLine: { type: :object, required: %w[product unit date quantity],
                       properties: { product: { type: :string, description: "Código do produto" }, unit: { type: :string }, date: { type: :string, format: :date },
                                     quantity: { type: :number }, note: { type: :string, nullable: true } } },
          Order: { type: :object, required: %w[customer week_start lines],
                   properties: { customer: { type: :string }, week_start: { type: :string, format: :date }, lines: { type: :array, items: { "$ref" => "#/components/schemas/OrderLine" } },
                                 changed_dates: { type: :array, items: { type: :string, format: :date }, description: "Só no PUT: dias de entrega que mudaram" },
                                 stale_plans: { type: :array, items: { type: :string, format: :date }, description: "Só no PUT: dias com produção enviada que mudou" } } },
          OrderUpdate: { type: :object, required: %w[customer week lines],
                         properties: { customer: { type: :string, example: "hbp" }, week: { type: :string, format: :date, example: "2026-10-12", description: "Segunda-feira da semana" },
                                       lines: { type: :array, items: { type: :object, required: %w[product date quantity],
                                                                       properties: { product: { type: :string, example: "cenoura_cubinhos" }, date: { type: :string, format: :date, example: "2026-10-14" },
                                                                                     quantity: { oneOf: [ { type: :number }, { type: :string } ], example: "12,5", description: "0 ou vazio apaga a linha" },
                                                                                     unit: { type: :string, description: "Padrão: a unidade do produto" } } } } } },
          Change: { type: :object, properties: { label: { type: :string }, unit: { type: :string }, before: { type: :number, nullable: true }, after: { type: :number, nullable: true },
                                                 kind: { type: :string, enum: %w[added removed changed] } } },
          PlanVersion: { type: :object, nullable: true, properties: { version: { type: :integer }, sent_at: { type: :string, format: "date-time" } } },
          Schedule: { type: :object, required: %w[date customers],
                      properties: { date: { type: :string, format: :date },
                                    customers: { type: :array, items: { type: :object, properties: { customer: { "$ref" => "#/components/schemas/Customer" },
                                                                                                     items: { type: :array, items: { type: :object, properties: {
                                                                                                       product: { type: :string }, name: { type: :string }, quantity: { type: :number }, unit: { type: :string },
                                                                                                       production_date: { type: :string, format: :date, nullable: true }, note: { type: :string, nullable: true } } } } } } } } },
          Production: { type: :object, required: %w[date items aprontes],
                        properties: { date: { type: :string, format: :date }, sent_version: { "$ref" => "#/components/schemas/PlanVersion" },
                                      changes_since_sent: { type: :array, items: { "$ref" => "#/components/schemas/Change" } },
                                      items: { type: :array, items: { type: :object, properties: { product: { type: :string }, name: { type: :string }, sector: { type: :string },
                                                                                                    quantity: { type: :number }, unit: { type: :string },
                                                                                                    breakdown: { type: :array, items: { type: :object, properties: { customer: { type: :string }, delivery_date: { type: :string, format: :date }, quantity: { type: :number } } } } } } },
                                      aprontes: { type: :array, items: { type: :object, properties: { raw_material: { type: :string }, kg: { type: :number }, boxes: { type: :integer } } } } } },
          Purchase: { type: :object, required: %w[items],
                      properties: { date: { type: :string, format: :date, nullable: true }, sent_version: { "$ref" => "#/components/schemas/PlanVersion" },
                                    changes_since_sent: { type: :array, items: { "$ref" => "#/components/schemas/Change" } },
                                    items: { type: :array, items: { type: :object, properties: { raw_material: { type: :string }, name: { type: :string }, supplier: { type: :string, nullable: true },
                                                                                                  unit: { type: :string }, kg: { type: :number }, stock_kg: { type: :number }, net_kg: { type: :number },
                                                                                                  packages: { type: :integer, nullable: true }, package: { type: :string }, missing_factor: { type: :boolean } } } } } },
          Stock: { type: :object, required: %w[date counts previous],
                   properties: { date: { type: :string, format: :date },
                                 counts: { type: :array, items: { type: :object, properties: { raw_material: { type: :string }, kg: { type: :number } } } },
                                 previous: { type: :array, description: "Última contagem anterior de cada matéria-prima",
                                             items: { type: :object, properties: { raw_material: { type: :string }, kg: { type: :number }, date: { type: :string, format: :date } } } } } },
          StockUpdate: { type: :object, required: %w[date counts],
                         properties: { date: { type: :string, format: :date, example: "2026-10-13" },
                                       counts: { type: :array, items: { type: :object, required: %w[raw_material],
                                                                        properties: { raw_material: { type: :string, example: "cenoura" },
                                                                                      kg: { oneOf: [ { type: :number }, { type: :string }, { type: :null } ], example: "12,5", description: "Vazio ou nulo apaga a contagem; 0 é câmara vazia" } } } } } }
        }
      },
      security: [ { bearerAuth: [] } ]
    }
  }

  config.openapi_format = :yaml
end
