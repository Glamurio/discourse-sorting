# frozen_string_literal: true

module DiscourseSorting
  # One payment received through PayPal. Only the amount and date are kept: no name, no
  # e-mail address, nothing that identifies the donor.
  class Donation < ActiveRecord::Base
    self.table_name = "discourse_sorting_donations"

    validates :paypal_id, presence: true, uniqueness: true
    validates :amount_cents, numericality: { greater_than: 0 }

    # The current calendar month in UTC.
    def self.month_range(now = Time.now.utc)
      now.beginning_of_month..now.end_of_month
    end

    # Money received this month in the configured currency, minus refunds, in cents.
    def self.raised_cents(now = Time.now.utc)
      where(paid_at: month_range(now), currency: SiteSetting.discourse_sorting_donations_currency)
        .sum("amount_cents - refunded_cents")
        .to_i
    end

    # Stores one payment unless that payment id was already stored (providers deliver
    # webhooks more than once). Returns the record, or nil for a duplicate or bad data.
    def self.record(external_id:, kind:, amount:, currency:, paid_at:)
      return if external_id.blank? || amount.blank? || currency.blank?

      create!(
        paypal_id: external_id, # the provider's payment id, prefixed for non-PayPal ones ("kofi:...")
        kind: kind,
        amount_cents: to_cents(amount),
        currency: currency.to_s.upcase,
        paid_at: paid_at || Time.now.utc,
      ).tap { Discourse.cache.delete("discourse_sorting:donations") }
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid, ArgumentError
      nil
    end

    # "12.50" or "12" -> 1250 / 1200
    def self.to_cents(value)
      (BigDecimal(value.to_s) * 100).round.to_i
    end
  end
end
