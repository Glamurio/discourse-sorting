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
      raise Discourse::NotFound if !audience?

      render json: Discourse.cache.fetch("discourse_sorting:donations", expires_in: CACHE_TTL) { summary }
    end

    private

    def audience?
      case SiteSetting.discourse_sorting_donations_audience
      when "everyone"
        true
      when "staff"
        current_user&.staff?
      else
        current_user&.admin?
      end
    end

    def summary
      now = Time.now.utc
      begin
        Donation.convert_pending!(now)
      rescue StandardError => e
        Rails.logger.warn("[discourse-sorting] converting donations failed: #{e.message}")
      end
      goal_cents = SiteSetting.discourse_sorting_donations_goal.to_i * 100
      raised = Donation.raised_cents(now)

      {
        title: SiteSetting.discourse_sorting_donations_title,
        currency: SiteSetting.discourse_sorting_donations_currency,
        month: now.strftime("%Y-%m"),
        goal_cents: goal_cents,
        raised_cents: raised,
        message: SiteSetting.discourse_sorting_donations_message.presence,
        button_text: SiteSetting.discourse_sorting_donations_button_text,
        reached_text: SiteSetting.discourse_sorting_donations_reached_text,
        url: SiteSetting.discourse_sorting_donations_url.presence,
      }
    end
  end
end
