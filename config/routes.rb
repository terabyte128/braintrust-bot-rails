Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  telegram_webhook BotController

  root to: 'static_pages#index'
  post '/alexa', to: 'alexas#alexa'

  get '/get_photo/:id', to: 'static_pages#get_photo', as: 'get_photo'
end
