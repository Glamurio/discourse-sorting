# frozen_string_literal: true

# name: discourse-sorting
# about: Sorting fixes (order/ascending on /top, URL sorting on the User Portfolio page) plus the server side of the optional booru view (tag counts within a search, per-account opt-in).
# version: 0.2.0
# authors: Glamurio
# url: https://github.com/Glamurio/discourse-sorting
# required_version: 2026.1.0

enabled_site_setting :discourse_sorting_enabled

module ::DiscourseSorting
  PLUGIN_NAME = "discourse-sorting"
  BOORU_FIELD = "fluffy_booru"
end

require_relative "lib/discourse_sorting/engine"

after_initialize do
  require_relative "lib/discourse_sorting/topic_query_extension"

  # true / false once the person has chosen, nil while they have not.
  # Must be here, not at the top level: it touches ::User, which does not exist
  # yet while plugin.rb is first evaluated.
  register_user_custom_field_type DiscourseSorting::BOORU_FIELD, :boolean

  reloadable_patch { TopicQuery.prepend(DiscourseSorting::TopicQueryExtension) }

  add_to_serializer(:current_user, :fluffy_booru) do
    object.custom_fields[DiscourseSorting::BOORU_FIELD]
  end

  Discourse::Application.routes.append { mount ::DiscourseSorting::Engine, at: "/discourse-sorting" }
end
