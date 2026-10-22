# frozen_string_literal: true

DiscourseSorting::Engine.routes.draw do
  get "/tag-counts" => "tag_counts#index"
  put "/booru" => "preferences#update"
end
