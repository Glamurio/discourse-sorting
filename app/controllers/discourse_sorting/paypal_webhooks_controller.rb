# frozen_string_literal: true

module DiscourseSorting
  # POST /discourse-sorting/donations/paypal
  # PayPal calls this for every payment on the account. Nothing is trusted until PayPal
  # itself confirms the signature. Handled events:
  #   PAYMENT.SALE.COMPLETED      a subscription payment
  #   PAYMENT.CAPTURE.COMPLETED   a one-time payment (Donate button, checkout)
  #   PAYMENT.SALE.REFUNDED / PAYMENT.CAPTURE.REFUNDED   reduce the matching donation
  # Everything else is acknowledged and ignored. Answering non-2xx makes PayPal retry,
  # which is only wanted when verification could not be completed.
  class PaypalWebhooksController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       :preload_json,
                       raise: false

    def create
      raise Discourse::NotFound if !SiteSetting.discourse_sorting_donations_enabled
      return render(json: failed_json, status: 503) if !Paypal.configured?

      raw = request.raw_post
      if !Paypal.verify_webhook?(request.headers, raw)
        return render(json: failed_json, status: 400)
      end

      event = JSON.parse(raw)
      handle(event["event_type"], event["resource"] || {})
      render json: success_json
    rescue JSON::ParserError
      render json: failed_json, status: 400
    end

    private

    def handle(type, resource)
      case type
      when "PAYMENT.SALE.COMPLETED"
        record("sale", resource["id"], resource.dig("amount", "total"), resource.dig("amount", "currency"), resource["create_time"])
      when "PAYMENT.CAPTURE.COMPLETED"
        record("capture", resource["id"], resource.dig("amount", "value"), resource.dig("amount", "currency_code"), resource["create_time"])
      when "PAYMENT.SALE.REFUNDED"
        refund(resource["sale_id"], resource.dig("amount", "total"))
      when "PAYMENT.CAPTURE.REFUNDED"
        up = Array(resource["links"]).find { |l| l["rel"] == "up" }
        refund(up && up["href"].to_s.split("/").last, resource.dig("amount", "value"))
      end
    end

    def record(kind, paypal_id, amount, currency, time)
      Donation.record(
        external_id: paypal_id,
        kind: kind,
        amount: amount,
        currency: currency,
        paid_at: Time.zone.parse(time.to_s),
      )
    end

    def refund(paypal_id, amount)
      donation = Donation.find_by(paypal_id: paypal_id) if paypal_id.present?
      return if donation.nil? || amount.blank?

      refunded = [donation.refunded_cents + Donation.to_cents(amount), donation.amount_cents].min
      donation.update!(refunded_cents: refunded)
      Discourse.cache.delete("discourse_sorting:donations")
    end
  end
end
