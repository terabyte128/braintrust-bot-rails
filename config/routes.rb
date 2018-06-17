Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  telegram_webhook BotController

  root to: 'static_pages#index'
  post '/alexa', to: 'alexas#alexa'
end
