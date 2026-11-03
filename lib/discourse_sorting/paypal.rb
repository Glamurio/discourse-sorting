# frozen_string_literal: true

require "net/http"

module DiscourseSorting
  # The little of PayPal's REST API the donation tracker needs: checking that a webhook
  # really came from PayPal. Credentials come from site settings; the secret is a hidden
  # setting and is never logged or sent to the browser.
  class Paypal
    class Error < StandardError
    end

    def self.configured?
      SiteSetting.discourse_sorting_paypal_client_id.present? &&
        SiteSetting.discourse_sorting_paypal_client_secret.present? &&
        SiteSetting.discourse_sorting_paypal_webhook_id.present?
    end

    def self.base_url
      if SiteSetting.discourse_sorting_paypal_mode == "sandbox"
        "https://api-m.sandbox.paypal.com"
      else
        "https://api-m.paypal.com"
      end
    end

    # headers: the PayPal-* request headers; raw_body: the request body exactly as received.
    # Asks PayPal to verify the signature. Anything but an explicit SUCCESS is false.
    def self.verify_webhook?(headers, raw_body)
      token = access_token
      fields = {
        auth_algo: headers["PayPal-Auth-Algo"],
        cert_url: headers["PayPal-Cert-Url"],
        transmission_id: headers["PayPal-Transmission-Id"],
        transmission_sig: headers["PayPal-Transmission-Sig"],
        transmission_time: headers["PayPal-Transmission-Time"],
        webhook_id: SiteSetting.discourse_sorting_paypal_webhook_id,
      }
      return false if fields.values.any?(&:blank?)

      # the event goes in untouched, byte for byte, as PayPal requires
      body = fields.to_json.chomp("}") + %(,"webhook_event":#{raw_body}})

      response = post("/v1/notifications/verify-webhook-signature", body, bearer: token)
      response["verification_status"] == "SUCCESS"
    rescue Error, JSON::ParserError => e
      Rails.logger.warn("[discourse-sorting] PayPal webhook verification failed: #{e.message}")
      false
    end

    def self.access_token
      uri = URI("#{base_url}/v1/oauth2/token")
      request = Net::HTTP::Post.new(uri)
      request.basic_auth(
        SiteSetting.discourse_sorting_paypal_client_id,
        SiteSetting.discourse_sorting_paypal_client_secret,
      )
      request["Accept"] = "application/json"
      request.set_form_data("grant_type" => "client_credentials")

      parsed = JSON.parse(perform(uri, request))
      parsed["access_token"].presence || raise(Error, "no access token (check the client id/secret and mode)")
    end

    def self.post(path, body, bearer:)
      uri = URI("#{base_url}#{path}")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{bearer}"
      request["Content-Type"] = "application/json"
      request.body = body
      JSON.parse(perform(uri, request))
    end

    def self.perform(uri, request)
      response =
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
          http.request(request)
        end
      raise Error, "PayPal answered HTTP #{response.code}" if !response.is_a?(Net::HTTPSuccess)
      response.body
    rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
      raise Error, e.class.name
    end
  end
end
