class GithubRepository < ApplicationRecord
  has_many :push_events, dependent: :nullify

  validates :github_id, :full_name, :api_url, :raw_payload, :fetched_at, presence: true
  validates :github_id, :api_url, uniqueness: true
end
