require "rails_helper"

RSpec.describe Github::IngestionService do
  let(:events) { JSON.parse(File.read(Rails.root.join("spec/fixtures/github_events.json"))) }
  let(:user) { JSON.parse(File.read(Rails.root.join("spec/fixtures/github_user.json"))) }
  let(:repo) { JSON.parse(File.read(Rails.root.join("spec/fixtures/github_repo.json"))) }
  let(:rate_headers) do
    {
      "x-ratelimit-limit" => "60",
      "x-ratelimit-remaining" => "55",
      "x-ratelimit-reset" => (Time.current.to_i + 3600).to_s
    }
  end

  before do
    stub_request(:get, "https://api.github.com/events")
      .to_return(status: 200, body: events.to_json, headers: rate_headers)
    stub_request(:get, "https://api.github.com/users/TheOctocat")
      .to_return(status: 200, body: user.to_json, headers: rate_headers)
    stub_request(:get, "https://api.github.com/repos/octocat/Hello-World")
      .to_return(status: 200, body: repo.to_json, headers: rate_headers)
  end

  it "ingests only push events, enriches, and records a run" do
    run = described_class.new(sleep_fn: ->(_) {}).run_once!

    expect(run.status).to eq("completed")
    expect(run.push_events_seen).to eq(1)
    expect(run.push_events_persisted).to eq(1)
    expect(PushEvent.count).to eq(1)

    push = PushEvent.first
    expect(push.enrichment_status).to eq("enriched")
    expect(push.github_actor.login).to eq("TheOctocat")
    expect(push.github_repository.full_name).to eq("octocat/Hello-World")
  end

  it "skips duplicate events on subsequent runs" do
    service = described_class.new(sleep_fn: ->(_) {})
    service.run_once!
    run = service.run_once!

    expect(run.push_events_skipped).to eq(1)
    expect(PushEvent.count).to eq(1)
  end
end
