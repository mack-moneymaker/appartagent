Rails.application.routes.draw do
  root "pages#home"

  # Static pages
  get "pricing", to: "pages#pricing"
  get "how-it-works", to: "pages#how_it_works", as: :how_it_works

  # Auth
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  get "signup", to: "registrations#new"
  post "signup", to: "registrations#create"

  # Dashboard
  get "dashboard", to: "dashboard#index"

  # Resources
  resources :search_profiles do
    member do
      patch :refresh
    end
  end
  resources :saved_listings, only: [:index, :create, :update, :destroy]
  resources :alerts, only: [:index] do
    member do
      patch :mark_seen
    end
  end
  resources :listings, only: [:index, :show]
  resources :auto_replies, only: [:index, :create]
  resources :application_templates, except: [:show]

  # API (scraper)
  namespace :api do
    post "listings/import", to: "listings#import"
    resources :search_profiles, only: [:index] do
      collection do
        get :pending
      end
      member do
        patch :scraped
        patch :request_scrape
      end
    end
  end

  # Health check
  get "up", to: "rails/health#show", as: :rails_health_check
end
