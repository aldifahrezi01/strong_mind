Rails.application.routes.draw do
  get "health", to: "health#show"
  get "push_events", to: "push_events#index"
  get "push_events/:id", to: "push_events#show"
end
