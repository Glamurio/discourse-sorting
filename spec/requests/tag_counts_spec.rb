# frozen_string_literal: true

# NOTE: written against core's spec conventions but not yet run.
RSpec.describe DiscourseSorting::TagCountsController do
  fab!(:foal) { Fabricate(:tag, name: "foal") }
  fab!(:crying) { Fabricate(:tag, name: "crying") }
  fab!(:secret) { Fabricate(:tag, name: "secret-tag") }
  fab!(:topic_1) { Fabricate(:topic, tags: [foal, crying]) }
  fab!(:topic_2) { Fabricate(:topic, tags: [foal]) }
  fab!(:topic_3) { Fabricate(:topic, tags: [crying, secret]) }

  before do
    SiteSetting.discourse_sorting_enabled = true
    SiteSetting.tagging_enabled = true
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [secret.name])
  end

  def counts
    response.parsed_body["tags"].to_h { |t| [t["name"], t["count"]] }
  end

  it "counts tags among the topics of the query" do
    get "/discourse-sorting/tag-counts.json", params: { q: "tag:foal" }
    expect(response.status).to eq(200)
    expect(counts).to eq("foal" => 2, "crying" => 1)
  end

  it "counts across everything for an empty query" do
    get "/discourse-sorting/tag-counts.json"
    expect(counts["foal"]).to eq(2)
    expect(counts["crying"]).to eq(2)
  end

  it "never returns hidden tags to people who cannot see them" do
    get "/discourse-sorting/tag-counts.json"
    expect(counts).not_to have_key("secret-tag")
  end

  it "honours exclusions" do
    get "/discourse-sorting/tag-counts.json", params: { q: "-tag:foal" }
    expect(counts.keys).to contain_exactly("crying")
  end

  it "does nothing when the plugin is disabled" do
    SiteSetting.discourse_sorting_enabled = false
    get "/discourse-sorting/tag-counts.json"
    expect(response.status).to eq(404)
  end
end
