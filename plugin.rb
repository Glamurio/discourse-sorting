# frozen_string_literal: true

# name: discourse-sorting
# about: Makes the order/ascending sort parameters behave consistently (including /top with a period) and lets the User Portfolio page be sorted through the URL.
# version: 0.1.0
# authors: Glamurio
# url: https://github.com/Glamurio/discourse-sorting
# required_version: 2026.1.0

enabled_site_setting :discourse_sorting_enabled

module ::DiscourseSorting
  PLUGIN_NAME = "discourse-sorting"
end

after_initialize do
  require_relative "lib/discourse_sorting/topic_query_extension"

  reloadable_patch { TopicQuery.prepend(DiscourseSorting::TopicQueryExtension) }
end
