# frozen_string_literal: true

module DiscourseSorting
  # GET /discourse-sorting/tag-counts.json?q=<filter query>
  #
  # How often each tag occurs among the topics a /filter search would list, like the
  # tag column on a booru. The topic set comes from the same code path as /filter
  # (permissions, muted topics and every filter term behave identically); hidden tags
  # are never returned.
  class TagCountsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    MAX_QUERY_LENGTH = 500

    def index
      query = params[:q].to_s.first(MAX_QUERY_LENGTH)
      max_topics = SiteSetting.discourse_sorting_tag_counts_max_topics

      scope = TopicQuery.new(current_user).fluffy_filter_scope(query)
      topic_ids =
        scope.except(:order, :limit, :offset).limit(max_topics + 1).pluck("topics.id").uniq

      truncated = topic_ids.length > max_topics
      topic_ids = topic_ids.first(max_topics)

      counts = TopicTag.where(topic_id: topic_ids)
      hidden_ids = DiscourseTagging.hidden_tags(guardian).pluck(:id)
      counts = counts.where.not(tag_id: hidden_ids) if hidden_ids.present?
      counts =
        counts
          .group(:tag_id)
          .order(Arel.sql("COUNT(*) DESC, tag_id ASC"))
          .limit(SiteSetting.discourse_sorting_tag_counts_limit)
          .count

      names = Tag.where(id: counts.keys).pluck(:id, :name).to_h

      render json: {
               tags:
                 counts.filter_map do |tag_id, count|
                   name = names[tag_id]
                   { name: name, count: count } if name
                 end,
               total_topics: topic_ids.length,
               truncated: truncated,
             }
    end
  end
end
