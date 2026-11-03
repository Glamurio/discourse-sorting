# frozen_string_literal: true

require "net/http"

module DiscourseSorting
  # Exchange rates from the European Central Bank, through frankfurter.dev (free, no key).
  # Covers the ~30 currencies the ECB publishes. Rates are cached for 12 hours; a failed
  # lookup is remembered for 10 minutes so a broken connection is not hammered.
  module ExchangeRates
    URL = "https://api.frankfurter.dev/v1/latest"
    TTL = 12.hours
    FAILURE_TTL = 10.minutes

    # Multiply an amount in `from` by this to get `to`. nil when unavailable.
    def self.rate(from, to)
      from = from.to_s.upcase
      to = to.to_s.upcase
      return BigDecimal("1") if from == to
      return if from.blank? || to.blank?

      return if Discourse.cache.read("discourse_sorting:rate_failed:#{from}:#{to}")

      cached = Discourse.cache.read("discourse_sorting:rate:#{from}:#{to}")
      return BigDecimal(cached) if cached

      value = fetch(from, to)
      if value
        Discourse.cache.write("discourse_sorting:rate:#{from}:#{to}", value.to_s, expires_in: TTL)
      else
        Discourse.cache.write("discourse_sorting:rate_failed:#{from}:#{to}", "1", expires_in: FAILURE_TTL)
      end
      value
    end

    def self.fetch(from, to)
      uri = URI("#{URL}?base=#{from}&symbols=#{to}")
      response =
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
          http.get(uri.request_uri, "Accept" => "application/json")
        end
      return log("HTTP #{response.code} for #{from}->#{to}") if !response.is_a?(Net::HTTPSuccess)

      value = JSON.parse(response.body).dig("rates", to)
      value.present? ? BigDecimal(value.to_s) : log("no #{from}->#{to} rate in the answer")
    rescue StandardError => e
      log("#{e.class}: #{e.message}")
    end

    def self.log(message)
      Rails.logger.warn("[discourse-sorting] exchange rate lookup failed: #{message}")
      nil
    end
  end
end
