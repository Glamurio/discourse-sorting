# frozen_string_literal: true

# NOTE: written against core's spec conventions but not yet run.
RSpec.describe DiscourseSorting::PreferencesController do
  fab!(:user)

  before { SiteSetting.discourse_sorting_enabled = true }

  it "requires login" do
    put "/discourse-sorting/booru.json", params: { enabled: true }
    expect(response.status).to eq(403)
  end

  it "saves the choice on the account" do
    sign_in(user)

    put "/discourse-sorting/booru.json", params: { enabled: true }
    expect(response.status).to eq(200)
    expect(user.reload.custom_fields[DiscourseSorting::BOORU_FIELD]).to eq(true)

    put "/discourse-sorting/booru.json", params: { enabled: false }
    expect(user.reload.custom_fields[DiscourseSorting::BOORU_FIELD]).to eq(false)
  end

  it "rejects a missing or invalid value" do
    sign_in(user)

    put "/discourse-sorting/booru.json"
    expect(response.status).to eq(400)

    put "/discourse-sorting/booru.json", params: { enabled: "maybe" }
    expect(response.status).to eq(400)
  end

  it "exposes the choice to the client, null until chosen" do
    sign_in(user)
    get "/session/current.json"
    expect(response.parsed_body["current_user"]).to have_key("fluffy_booru")
    expect(response.parsed_body["current_user"]["fluffy_booru"]).to be_nil
  end
end
