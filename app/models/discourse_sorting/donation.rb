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

    # Money received this month, refunds taken off, converted into the goal currency, in
    # cents. Payments whose rate is not known yet count as soon as the hourly job (or the
    # next summary) manages to fetch it.
    def self.raised_cents(now = Time.now.utc)
      where(paid_at: month_range(now), rate_currency: goal_currency)
        .where.not(rate: nil)
        .sum("(amount_cents - refunded_cents) * rate")
        .round
        .to_i
    end

    def self.goal_currency
      SiteSetting.discourse_sorting_donations_currency
    end

    # Give this month's payments a rate into the current goal currency where they have
    # none (rate lookup failed earlier, or the goal currency was changed).
    def self.convert_pending!(now = Time.now.utc)
      where(paid_at: month_range(now))
        .where("rate IS NULL OR rate_currency IS DISTINCT FROM ?", goal_currency)
        .find_each(&:apply_rate!)
    end

    def apply_rate!
      goal = self.class.goal_currency
      value = ExchangeRates.rate(currency, goal)
      update_columns(rate: value, rate_currency: goal) if value
      value
    end

    # Stores one payment unless that payment id was already stored (providers deliver
    # webhooks more than once). Returns the record, or nil for a duplicate or bad data.
    def self.record(external_id:, kind:, amount:, currency:, paid_at:)
      return if external_id.blank? || amount.blank? || currency.blank?

      donation =
        create!(
          paypal_id: external_id, # the provider's payment id, prefixed for non-PayPal ones ("kofi:...")
          kind: kind,
          amount_cents: to_cents(amount),
          currency: currency.to_s.upcase,
          paid_at: paid_at || Time.now.utc,
        )
      donation.apply_rate!
      Discourse.cache.delete("discourse_sorting:donations")
      donation
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid, ArgumentError
      nil
    end

    # "12.50" or "12" -> 1250 / 1200
    def self.to_cents(value)
      (BigDecimal(value.to_s) * 100).round.to_i
    end
  end
end
