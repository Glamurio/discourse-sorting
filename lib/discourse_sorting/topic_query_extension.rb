# frozen_string_literal: true

module DiscourseSorting
  # Core's `/top` list builds its ranking order inside `list_top_for`, but the
  # `order` / `ascending` request parameters are applied earlier, in
  # `default_results`. The result is `ORDER BY created_at DESC, <top score> DESC`:
  # the requested order wins and the period ranking is lost. In practice
  # `/top?period=yearly&order=created` and `/top?period=all&order=created`
  # return the same list, because the period only acts as an "any activity" filter.
  #
  # This extension changes the meaning when a sort is requested explicitly:
  #
  #   1. take the top N topics of the period by their normal top score
  #      (N = discourse_sorting_top_candidates), respecting every other filter
  #      (category, tags, muted, permissions, ...)
  #   2. sort only that set by the requested `order` / `ascending`
  #
  # Requests without an explicit `order` are untouched and go to core.
  module TopicQueryExtension
    def list_top_for(period)
      return super unless fluffy_sort_requested?

      score_column = TopTopic.score_column_for_period(period) # whitelisted column name

      create_list(:top, unordered: true, skip_ordering: true) do |topics|
        topics = remove_muted(topics, user, options)
        topics = topics.joins(:top_topic).where("top_topics.#{score_column} > 0")

        # default_results already applied pagination; take it off while ranking
        per_page = topics.limit_value
        offset = topics.offset_value
        unpaged = topics.except(:limit, :offset, :order)

        ranked_ids =
          unpaged
            .order(Arel.sql("COALESCE(top_topics.#{score_column}, 0) DESC, topics.bumped_at DESC"))
            .limit(SiteSetting.discourse_sorting_top_candidates)
            .pluck("topics.id")

        sorted = apply_ordering(unpaged.where(topics: { id: ranked_ids }), options)
        # stable tie-break so offset pagination does not repeat or skip rows
        sorted = sorted.order("topics.id DESC")
        sorted = sorted.limit(per_page) if per_page
        sorted = sorted.offset(offset) if offset.to_i > 0
        sorted
      end
    end

    # The topics a /filter search for `query` would list, without ordering or paging.
    # Public wrapper around core's private `filter_results`, used by the tag counts.
    def fluffy_filter_scope(query)
      scope, _topics_filter = filter_results(query)
      scope
    end

    private

    def fluffy_sort_requested?
      SiteSetting.discourse_sorting_enabled &&
        TopicQuery::SORTABLE_MAPPING.key?(@options[:order].to_s)
    end
  end
end
