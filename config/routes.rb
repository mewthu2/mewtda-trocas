Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users, path: "", path_names: { sign_in: "entrar", sign_out: "sair" }

  # Página pública do cliente final (sem login). O token é o slug de ExchangeConfig.
  scope "troca/:token", as: :public_exchange, controller: "public/exchanges" do
    get "/", action: :new
    post "buscar", action: :lookup, as: :lookup
    post "/", action: :create
    get "acompanhar/:code", action: :tracking, as: :tracking
  end
  get "crm/troca/:token", to: redirect("/troca/%{token}")

  authenticated :user do
    root "exchange_requests#index", as: :authenticated_root
  end
  root to: redirect("/entrar")

  resources :exchange_requests, path: "solicitacoes", only: %i[index show update] do
    member do
      post :return_label, path: "postagem"
    end
    resources :exchange_refunds, path: "reembolsos", only: %i[create update]
  end

  resource :exchange_config, path: "configuracao", only: %i[edit update] do
    get :rules, path: "regras"
    get :reasons, path: "motivos"
    get :resolutions, path: "resultados"
    get :shipping, path: "frete"
    get :email_templates, path: "comunicacao"
    post :test_correios, path: "frete/testar"
  end
  resource :email_domain, path: "configuracao/dominio-de-envio", only: %i[create update destroy]

  resource :current_client, path: "cliente", only: :update
  get "como-usar", to: "help#show", as: :help
end
