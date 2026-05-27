FactoryBot.define do
  factory :push_event do
    sequence(:github_event_id) { |n| "event-#{n}" }
    raw_payload do
      {
        "id" => github_event_id,
        "type" => "PushEvent",
        "actor" => { "id" => 1, "login" => "actor", "url" => "https://api.github.com/users/actor" },
        "repo" => { "id" => 10, "name" => "org/repo", "url" => "https://api.github.com/repos/org/repo" },
        "payload" => {
          "push_id" => 42,
          "ref" => "refs/heads/main",
          "head" => "abc",
          "before" => "def"
        }
      }
    end
    repository_github_id { 10 }
    push_id { 42 }
    ref { "refs/heads/main" }
    head { "abc123" }
    before { "def456" }
    enrichment_status { "pending" }
    github_created_at { Time.current }
  end
end
