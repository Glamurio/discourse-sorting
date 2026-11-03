# frozen_string_literal: true

DiscourseSorting::Engine.routes.draw do
  get "/tag-counts" => "tag_counts#index"
  get "/tag-counts/restricted" => "tag_counts#restricted"
  put "/booru" => "preferences#update"
  get "/donations" => "donations#index"
  post "/donations/paypal" => "paypal_webhooks#create"
  post "/donations/kofi" => "kofi_webhooks#create"
end
