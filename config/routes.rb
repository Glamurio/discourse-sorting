# frozen_string_literal: true

DiscourseSorting::Engine.routes.draw do
  get "/tag-counts" => "tag_counts#index"
  get "/tag-counts/restricted" => "tag_counts#restricted"
  put "/booru" => "preferences#update"
end
