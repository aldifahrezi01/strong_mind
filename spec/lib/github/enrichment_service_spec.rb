require "rails_helper"

RSpec.describe Github::EnrichmentService do
  let(:push_event) { create(:push_event) }

  it "reuses cached actor and repository records" do
    actor = GithubActor.create!(
      github_id: 1,
      login: "actor",
      api_url: "https://api.github.com/users/actor",
      raw_payload: { "login" => "actor" },
      fetched_at: Time.current
    )
    repository = GithubRepository.create!(
      github_id: 10,
      full_name: "org/repo",
      api_url: "https://api.github.com/repos/org/repo",
      raw_payload: { "full_name" => "org/repo" },
      fetched_at: Time.current
    )

    expect_any_instance_of(Github::Client).not_to receive(:fetch_resource)

    result = described_class.new.enrich!(push_event)
    expect(result).to be(true)
    expect(push_event.reload.github_actor).to eq(actor)
    expect(push_event.github_repository).to eq(repository)
  end
end
