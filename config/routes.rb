Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resource :account_password, only: %i[edit update], path: "conta/senha"
  resources :users, only: %i[index new create edit update] do
    post :reset_password, on: :member
  end
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#show"

  get "orders", to: "orders#index"
  patch "orders", to: "orders#update"

  resources :order_imports, only: %i[new create show] do
    member do
      post :apply
      patch :grid
      patch :settings
    end
  end

  get "schedule", to: "schedules#show"
  get "production", to: "productions#show"
  post "production/publish", to: "productions#publish", as: :publish_production
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
    resources :customers, path: "clientes", except: :show do
      resources :customer_aliases, path: "apelidos", only: %i[create destroy]
    end
  end

  get "estoque", to: "stocks#show", as: :stock
  patch "estoque", to: "stocks#update"

  get "conference", to: "conferences#show"
  get "conference/sheets", to: "conferences#sheets", as: :conference_sheets
end
