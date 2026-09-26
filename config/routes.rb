Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # No logins, so the site is read-only. Recipes are added only through the
  # token-protected API; fix a bad import by re-running the skill with --overwrite.
  resources :recipes, only: %i[index show]

  namespace :api do
    resources :recipes, only: :create
  end

  root "recipes#index"
end
