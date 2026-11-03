# frozen_string_literal: true

module DiscourseSorting
  # GET /discourse-sorting/donations.json
  # What the thermometer shows: this month's total, the goal, and the donate link.
  # Totals only; nothing about who donated.
  class DonationsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    # Short cache so a busy front page costs one query a minute.
    CACHE_TTL = 1.minute

    def index
      raise Discourse::NotFound if !SiteSetting.discourse_sorting_donations_enabled

      render json: Discourse.cache.fetch("discourse_sorting:donations", expires_in: CACHE_TTL) { summary }
    end

    private

    def summary
      now = Time.now.utc
      goal_cents = SiteSetting.discourse_sorting_donations_goal.to_i * 100
      raised = Donation.raised_cents(now)

      {
        title: SiteSetting.discourse_sorting_donations_title,
        currency: SiteSetting.discourse_sorting_donations_currency,
        month: now.strftime("%Y-%m"),
        goal_cents: goal_cents,
        raised_cents: raised,
        url: SiteSetting.discourse_sorting_donations_url.presence,
      }
    end
  end
end
