Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "orders#index"

  get "orders", to: "orders#index"
  patch "orders", to: "orders#update"

  resources :order_imports, only: %i[new create show] do
    post :apply, on: :member
  end

  get "schedule", to: "schedules#show"
  get "production", to: "productions#show"
  post "production/publish", to: "productions#publish", as: :publish_production
  get "purchases", to: "purchases#show"
  post "purchases/publish", to: "purchases#publish", as: :publish_purchase
  get "conference", to: "conferences#show"
  get "conference/sheets", to: "conferences#sheets", as: :conference_sheets
end
