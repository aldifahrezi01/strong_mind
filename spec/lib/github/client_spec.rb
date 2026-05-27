require "rails_helper"

RSpec.describe Github::Client do
  let(:rate_headers) do
    {
      "x-ratelimit-limit" => "60",
      "x-ratelimit-remaining" => "59",
      "x-ratelimit-reset" => (Time.current.to_i + 3600).to_s
    }
  end

  describe "#fetch_events" do
    it "returns parsed events and tracks rate limits" do
      events = JSON.parse(File.read(Rails.root.join("spec/fixtures/github_events.json")))
      stub_request(:get, "https://api.github.com/events")
        .to_return(status: 200, body: events.to_json, headers: rate_headers)

      client = described_class.new
      result = client.fetch_events

      expect(result.size).to eq(2)
      expect(client.rate_limit_tracker.remaining).to eq(59)
    end

    it "raises when rate limited" do
      stub_request(:get, "https://api.github.com/events")
        .to_return(
          status: 403,
          body: { message: "API rate limit exceeded" }.to_json,
          headers: rate_headers.merge("x-ratelimit-remaining" => "0")
        )

      expect { described_class.new.fetch_events }.to raise_error(Github::Client::RateLimitExceeded)
    end
  end
end
