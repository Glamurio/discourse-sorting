# frozen_string_literal: true

# NOTE: written against core's spec conventions but not yet run.
RSpec.describe DiscourseSorting::TopicQueryExtension do
  fab!(:user)
  fab!(:old_popular) { Fabricate(:topic, created_at: 10.days.ago) }
  fab!(:new_quiet) { Fabricate(:topic, created_at: 1.day.ago) }
  fab!(:newest_quiet) { Fabricate(:topic, created_at: 1.hour.ago) }

  before do
    SiteSetting.discourse_sorting_enabled = true
    TopTopic.refresh!
    TopTopic.where(topic_id: old_popular.id).update_all(all_score: 100)
    TopTopic.where(topic_id: new_quiet.id).update_all(all_score: 10)
    TopTopic.where(topic_id: newest_quiet.id).update_all(all_score: 5)
  end

  def top_ids(options = {})
    TopicQuery.new(user, options).list_top_for(:all).topics.map(&:id)
  end

  it "leaves ranking alone when no order is requested" do
    expect(top_ids).to eq([old_popular.id, new_quiet.id, newest_quiet.id])
  end

  it "sorts the ranked set by the requested order" do
    expect(top_ids(order: "created")).to eq([newest_quiet.id, new_quiet.id, old_popular.id])
  end

  it "supports ascending" do
    expect(top_ids(order: "created", ascending: "true")).to eq(
      [old_popular.id, new_quiet.id, newest_quiet.id],
    )
  end

  it "only sorts the top candidates, so the period still matters" do
    SiteSetting.discourse_sorting_top_candidates = 20 # minimum allowed
    extra = Fabricate.times(25, :topic, created_at: 20.days.ago)
    TopTopic.refresh!
    TopTopic.where(topic_id: extra.map(&:id)).update_all(all_score: 1)
    TopTopic.where(topic_id: old_popular.id).update_all(all_score: 100)
    TopTopic.where(topic_id: new_quiet.id).update_all(all_score: 10)
    TopTopic.where(topic_id: newest_quiet.id).update_all(all_score: 5)

    ids = top_ids(order: "created")
    expect(ids.length).to eq(20)
    expect(ids).to include(old_popular.id, new_quiet.id, newest_quiet.id)
  end

  it "falls back to core behaviour when disabled" do
    SiteSetting.discourse_sorting_enabled = false
    expect(top_ids(order: "created").first).to eq(newest_quiet.id)
  end
end
