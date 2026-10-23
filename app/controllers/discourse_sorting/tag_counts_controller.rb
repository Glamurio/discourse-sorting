# frozen_string_literal: true

module DiscourseSorting
  # GET /discourse-sorting/tag-counts.json?q=<filter query>
  #
  # How often each tag occurs among the topics a /filter search would list, like the
  # tag column on a booru. The topic set comes from the same code path as /filter
  # (permissions, muted topics and every filter term behave identically); hidden tags
  # are never returned.
  #
  # The work is a scan over every topic matching the search, so two things protect the
  # server: answers are cached for a few minutes (per person, because what someone may
  # see differs), and each person or address is rate limited.
  class TagCountsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    MAX_QUERY_LENGTH = 500
    CACHE_TTL = 5.minutes

    def index
      apply_rate_limit

      query = params[:q].to_s.first(MAX_QUERY_LENGTH).strip
      key = "discourse_sorting:tag_counts:#{current_user&.id || "anon"}:#{Digest::SHA1.hexdigest(query.downcase)}"

      result = Discourse.cache.fetch(key, expires_in: CACHE_TTL) { compute(query) }

      render json: result
    end

    # GET /discourse-sorting/tag-counts/restricted.json
    # Names of tags the current person may not use (see restricted_tag_ids). The sidebar
    # hides these, so tags reserved for members of certain groups are only listed to them.
    def restricted
      names = Tag.where(id: restricted_tag_ids).pluck(:name)
      render json: { tags: names }
    end

    private

    # Tags in a tag group that has permission rows, when none of those rows lets one of
    # this person's groups (or "everyone") use the tag. Same rule Discourse applies when
    # tagging. Admins are never restricted. Tags in no tag group, or in a group without
    # permission rows, are free to everyone.
    def restricted_tag_ids
      return [] if current_user&.admin?

      group_ids = [Group::AUTO_GROUPS[:everyone]]
      group_ids |= current_user.group_ids if current_user

      full = TagGroupPermission.permission_types[:full]
      with_rules = TagGroupPermission.distinct.pluck(:tag_group_id)
      allowed =
        TagGroupPermission.where(group_id: group_ids, permission_type: full).distinct.pluck(
          :tag_group_id,
        )
      blocked = with_rules - allowed
      return [] if blocked.empty?

      # a tag that also sits in a group this person may use is not restricted
      TagGroupMembership.where(tag_group_id: blocked).distinct.pluck(:tag_id) -
        TagGroupMembership.where(tag_group_id: allowed).distinct.pluck(:tag_id)
    end

    def apply_rate_limit
      if current_user
        RateLimiter.new(current_user, "booru-tag-counts", 60, 1.minute).performed!
      else
        RateLimiter.new(
          nil,
          "booru-tag-counts-#{request.remote_ip}",
          30,
          1.minute,
          global: true,
        ).performed!
      end
    end

    def compute(query)
      max_topics = SiteSetting.discourse_sorting_tag_counts_max_topics

      scope = TopicQuery.new(current_user).fluffy_filter_scope(query)
      topic_ids =
        scope.except(:order, :limit, :offset).limit(max_topics + 1).pluck("topics.id").uniq

      truncated = topic_ids.length > max_topics
      topic_ids = topic_ids.first(max_topics)

      counts = TopicTag.where(topic_id: topic_ids)
      hidden_ids = DiscourseTagging.hidden_tags(guardian).pluck(:id)
      hidden_ids |= restricted_tag_ids
      counts = counts.where.not(tag_id: hidden_ids) if hidden_ids.present?
      counts =
        counts
          .group(:tag_id)
          .order(Arel.sql("COUNT(*) DESC, tag_id ASC"))
          .limit(SiteSetting.discourse_sorting_tag_counts_limit)
          .count

      names = Tag.where(id: counts.keys).pluck(:id, :name).to_h

      {
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
