Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users, path: "", path_names: { sign_in: "entrar", sign_out: "sair" }

  # Página pública do cliente final (sem login). O token é o slug de
  # ExchangeConfig — o mesmo usado no painel, então basta trocar o domínio.
  scope "troca/:token", as: :public_exchange, controller: "public/exchanges" do
    get "/", action: :new
    post "buscar", action: :lookup, as: :lookup
    post "/", action: :create
  end
  get "crm/troca/:token", to: redirect("/troca/%{token}")

  authenticated :user do
    root "exchange_requests#index", as: :authenticated_root
  end
  root to: redirect("/entrar")

  resources :exchange_requests, path: "solicitacoes", only: %i[index show update]
  resource :exchange_config, path: "configuracao", only: %i[edit update] do
    get :email_templates, path: "emails"
  end
  resource :current_client, path: "cliente", only: :update
end
