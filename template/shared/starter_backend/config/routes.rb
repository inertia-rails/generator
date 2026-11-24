# frozen_string_literal: true

Rails.application.routes.draw do
  get  "sign_in", to: "sessions#new", as: :sign_in
  post "sign_in", to: "sessions#create"
  get  "sign_up", to: "users#new", as: :sign_up
  post "sign_up", to: "users#create"

  resources :sessions, only: [ :destroy ]
  resource :users, only: [ :destroy ]

  namespace :identity do
    resource :email_verification, only: [ :show, :create ]
    resource :password_reset,     only: [ :new, :edit, :create, :update ]
  end

<% if use_teams %>
  resources :invitations, only: [ :destroy ], param: :code do
    post :accept, on: :member
  end

<% end %>
  get :dashboard, to: "dashboard#index"
<% if use_teams %>

  # Pages that belong to a team carry it in the URL
  scope ":team_id", as: :team do
    get :dashboard, to: "dashboard#show"
  end
<% end %>

  namespace :settings do
    resource :profile, only: [ :show, :update ]
    resource :password, only: [ :show, :update ]
    resource :email, only: [ :show, :update ]
    resources :sessions, only: [ :index ]
<% if use_teams %>
    resources :teams, only: [ :index, :create, :show, :update, :destroy ] do
      delete :leave, on: :member

      scope module: :teams do
        resources :members, only: [ :update, :destroy ]
        resources :invitations, only: [ :create, :destroy ], param: :code
      end
    end
<% end %>
    inertia :appearance
  end

  root "home#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
