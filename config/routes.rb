Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :api_tokens, only: %i[index new create destroy], path: "chaves-api"
  resource :account_password, only: %i[edit update], path: "conta/senha"
  resources :users, only: %i[index new create edit update] do
    post :reset_password, on: :member
  end
  get "up" => "rails/health#show", as: :rails_health_check
  get "ready" => "readiness#show", as: :readiness_check

  # PWA: o manifesto deixa instalar na tela inicial e o service worker recebe os avisos de produção.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # API v1 (JSON, token por empresa) e a documentação OpenAPI gerada pelos specs (rswag).
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      %w[customers products raw_materials cuts suppliers].each { |name| get name, to: "catalog##{name}" }
      get "orders", to: "orders#show"
      put "orders", to: "orders#update"
      get "schedule", to: "plans#schedule"
      get "production", to: "plans#production"
      get "purchases", to: "plans#purchases"
      get "deliveries", to: "deliveries#index"
      get "stock", to: "stocks#show"
      put "stock", to: "stocks#update"
      # Tabelas planas para BI (JSON ou .csv).
      %w[schedule production purchases losses].each { |name| get "bi/#{name}", to: "bi##{name}" }
    end
  end

  root "home#show"
  get "painel", to: "dashboards#show", as: :dashboard
  get "bi", to: "indicators#show", as: :indicators

  get "orders", to: "orders#index"
  patch "orders", to: "orders#update"
  resources :order_versions, only: :show do
    post :restore, on: :member
  end

  resources :order_imports, only: %i[new create show] do
    member do
      post :apply
      post :undo
      patch :grid
      patch :settings
    end
  end

  get "schedule", to: "schedules#show"
  get "production", to: "productions#show"
  resource :push_subscription, only: %i[show create destroy], path: "avisos"
  resource :tour, only: :create
  get "como-funciona", to: "guides#show", as: :guide
  post "production/publish", to: "productions#publish", as: :publish_production
  get "production/versions/:id", to: "production_versions#show", as: :production_version
  get "purchases", to: "purchases#show"
  post "purchases/publish", to: "purchases#publish", as: :publish_purchase
  resource :rules, only: %i[show update], path: "regras"
  resources :purchase_days, only: %i[create destroy], path: "dias-de-compra"

  scope path: "cadastros" do
    resources :suppliers, path: "fornecedores", except: :show
    resources :raw_materials, path: "materias-primas", except: :show do
      patch :bulk_update, path: "lote", on: :collection
    end
    resources :products, path: "produtos", except: :show
    resources :cuts, path: "cortes", except: :show
    resources :customers, path: "clientes", except: :show do
      resources :customer_aliases, path: "apelidos", only: %i[create destroy]
    end
  end

  get "estoque", to: "stocks#show", as: :stock
  patch "estoque", to: "stocks#update"

  get "historico", to: "audit_logs#index", as: :audit_logs
  resources :companies, path: "empresas", only: %i[index new create edit update]

  get "conference", to: "conferences#show"
  get "conference/sheets", to: "conferences#sheets", as: :conference_sheets
  get "conference/sheets/import", to: "reference_sheets#new", as: :new_reference_sheets
  post "conference/sheets/import", to: "reference_sheets#create", as: :reference_sheets
  get "conference/sheets/imports/:id", to: "sheet_imports#show", as: :sheet_import
  post "conference/sheets/aliases", to: "sheet_aliases#create", as: :sheet_aliases
  post "conference/sheets/notes", to: "comparison_notes#create", as: :comparison_notes
  delete "conference/sheets/notes/:id", to: "comparison_notes#destroy", as: :comparison_note
end
