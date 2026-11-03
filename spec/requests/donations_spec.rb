# frozen_string_literal: true

# NOTE: written against core's spec conventions but not yet run.
RSpec.describe "Donation tracker" do
  before do
    SiteSetting.discourse_sorting_enabled = true
    SiteSetting.discourse_sorting_donations_enabled = true
    SiteSetting.discourse_sorting_donations_currency = "USD"
    SiteSetting.discourse_sorting_donations_goal = 50
    SiteSetting.discourse_sorting_paypal_client_id = "id"
    SiteSetting.discourse_sorting_paypal_client_secret = "secret"
    SiteSetting.discourse_sorting_paypal_webhook_id = "WH-1"
    Discourse.cache.delete("discourse_sorting:donations")
  end

  def post_event(type, resource)
    post "/discourse-sorting/donations/paypal",
         params: { event_type: type, resource: resource }.to_json,
         headers: {
           "CONTENT_TYPE" => "application/json",
         }
  end

  def sale(id, total, currency = "USD")
    { "id" => id, "amount" => { "total" => total, "currency" => currency }, "create_time" => Time.now.utc.iso8601 }
  end

  describe "webhook" do
    it "rejects events PayPal does not vouch for" do
      DiscourseSorting::Paypal.stubs(:verify_webhook?).returns(false)
      post_event("PAYMENT.SALE.COMPLETED", sale("S1", "5.00"))
      expect(response.status).to eq(400)
      expect(DiscourseSorting::Donation.count).to eq(0)
    end

    it "does nothing until PayPal is configured" do
      SiteSetting.discourse_sorting_paypal_webhook_id = ""
      post_event("PAYMENT.SALE.COMPLETED", sale("S1", "5.00"))
      expect(response.status).to eq(503)
    end

    context "when PayPal vouches for the event" do
      before { DiscourseSorting::Paypal.stubs(:verify_webhook?).returns(true) }

      it "records a subscription payment" do
        post_event("PAYMENT.SALE.COMPLETED", sale("S1", "5.00"))
        expect(response.status).to eq(200)
        expect(DiscourseSorting::Donation.sole.amount_cents).to eq(500)
      end

      it "records a one-time payment" do
        post_event(
          "PAYMENT.CAPTURE.COMPLETED",
          { "id" => "C1", "amount" => { "value" => "12.50", "currency_code" => "USD" }, "create_time" => Time.now.utc.iso8601 },
        )
        expect(DiscourseSorting::Donation.sole.amount_cents).to eq(1250)
      end

      it "counts a repeated delivery once" do
        2.times { post_event("PAYMENT.SALE.COMPLETED", sale("S1", "5.00")) }
        expect(response.status).to eq(200)
        expect(DiscourseSorting::Donation.count).to eq(1)
      end

      it "subtracts refunds" do
        post_event("PAYMENT.SALE.COMPLETED", sale("S1", "5.00"))
        post_event("PAYMENT.SALE.REFUNDED", { "sale_id" => "S1", "amount" => { "total" => "2.00", "currency" => "USD" } })
        expect(DiscourseSorting::Donation.raised_cents).to eq(300)
      end

      it "acknowledges events it does not use" do
        post_event("BILLING.SUBSCRIPTION.CREATED", {})
        expect(response.status).to eq(200)
        expect(DiscourseSorting::Donation.count).to eq(0)
      end
    end
  end

  describe "GET /discourse-sorting/donations.json" do
    it "reports this month's total and the goal, and nothing about donors" do
      DiscourseSorting::Donation.create!(paypal_id: "S1", kind: "sale", amount_cents: 1500, currency: "USD", paid_at: Time.now.utc)
      get "/discourse-sorting/donations.json"
      expect(response.parsed_body).to include("raised_cents" => 1500, "goal_cents" => 5000, "currency" => "USD")
      expect(response.parsed_body.keys).not_to include("donors", "donations")
    end

    it "leaves out other currencies and earlier months" do
      DiscourseSorting::Donation.create!(paypal_id: "E1", kind: "sale", amount_cents: 900, currency: "EUR", paid_at: Time.now.utc)
      DiscourseSorting::Donation.create!(paypal_id: "O1", kind: "sale", amount_cents: 700, currency: "USD", paid_at: 2.months.ago)
      get "/discourse-sorting/donations.json"
      expect(response.parsed_body["raised_cents"]).to eq(0)
    end

    it "is hidden while the feature is off" do
      SiteSetting.discourse_sorting_donations_enabled = false
      get "/discourse-sorting/donations.json"
      expect(response.status).to eq(404)
    end
  end
end

RSpec.describe "Ko-fi webhook" do
  before do
    SiteSetting.discourse_sorting_enabled = true
    SiteSetting.discourse_sorting_donations_enabled = true
    SiteSetting.discourse_sorting_donations_currency = "USD"
    SiteSetting.discourse_sorting_kofi_verification_token = "tok"
  end

  def kofi(overrides = {})
    data = {
      "verification_token" => "tok",
      "message_id" => "m1",
      "kofi_transaction_id" => "t1",
      "timestamp" => Time.now.utc.iso8601,
      "type" => "Donation",
      "amount" => "3.00",
      "currency" => "USD",
      "from_name" => "someone",
    }.merge(overrides)
    post "/discourse-sorting/donations/kofi", params: { data: data.to_json }
  end

  it "records a donation" do
    kofi
    expect(response.status).to eq(200)
    expect(DiscourseSorting::Donation.sole).to have_attributes(amount_cents: 300, paypal_id: "kofi:t1")
  end

  it "records a membership payment" do
    kofi("type" => "Subscription", "kofi_transaction_id" => "t2")
    expect(DiscourseSorting::Donation.sole.amount_cents).to eq(300)
  end

  it "counts a repeated delivery once" do
    2.times { kofi }
    expect(DiscourseSorting::Donation.count).to eq(1)
  end

  it "ignores shop orders" do
    kofi("type" => "Shop Order")
    expect(response.status).to eq(200)
    expect(DiscourseSorting::Donation.count).to eq(0)
  end

  it "rejects a wrong token" do
    kofi("verification_token" => "nope")
    expect(response.status).to eq(403)
    expect(DiscourseSorting::Donation.count).to eq(0)
  end

  it "does nothing until a token is set" do
    SiteSetting.discourse_sorting_kofi_verification_token = ""
    kofi
    expect(response.status).to eq(503)
  end

  it "rejects a malformed body" do
    post "/discourse-sorting/donations/kofi", params: { data: "not json" }
    expect(response.status).to eq(400)
  end
end
