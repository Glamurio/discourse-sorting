# frozen_string_literal: true

module DiscourseSorting
  # POST /discourse-sorting/donations/kofi
  # Ko-fi calls this for every payment on the page (Ko-fi > More > API > Webhooks). The
  # body is form-encoded with one field, `data`, holding a JSON string. Ko-fi has no
  # signature; it puts a private `verification_token` in the payload, which must match
  # the one in the site settings. Counted: Donation and Subscription payments. Shop
  # orders and commissions are purchases, not donations, so they are ignored.
  # Ko-fi sends no refund events.
  class KofiWebhooksController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       :preload_json,
                       raise: false

    COUNTED_TYPES = %w[Donation Subscription].freeze

    def create
      raise Discourse::NotFound if !SiteSetting.discourse_sorting_donations_enabled

      expected = SiteSetting.discourse_sorting_kofi_verification_token
      return render(json: failed_json, status: 503) if expected.blank?

      data = JSON.parse(params[:data].to_s)
      given = data["verification_token"].to_s
      if !ActiveSupport::SecurityUtils.secure_compare(given, expected)
        return render(json: failed_json, status: 403)
      end

      if COUNTED_TYPES.include?(data["type"])
        Donation.record(
          external_id: "kofi:#{data["kofi_transaction_id"].presence || data["message_id"]}",
          kind: "kofi_#{data["type"].downcase}",
          amount: data["amount"],
          currency: data["currency"],
          paid_at: Time.zone.parse(data["timestamp"].to_s),
        )
      end

      render json: success_json
    rescue JSON::ParserError
      render json: failed_json, status: 400
    end
  end
end
