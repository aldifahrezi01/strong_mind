class PushEvent < ApplicationRecord
  belongs_to :github_actor, optional: true
  belongs_to :github_repository, optional: true

  ENRICHMENT_STATUSES = %w[pending enriched failed].freeze

  validates :github_event_id, presence: true, uniqueness: true
  validates :raw_payload, presence: true
  validates :repository_github_id, :push_id, :ref, :head, :before, presence: true
  validates :enrichment_status, inclusion: { in: ENRICHMENT_STATUSES }

  scope :recent, -> { order(github_created_at: :desc) }
  scope :pending_enrichment, -> { where(enrichment_status: "pending") }

  def self.upsert_from_github_event!(event_hash)
    return nil unless event_hash["type"] == "PushEvent"

    github_event_id = event_hash["id"].to_s
    payload = event_hash["payload"] || {}
    repo = event_hash["repo"] || {}
    return nil if repo["id"].blank? || payload["push_id"].blank? || payload["ref"].blank?

    record = find_or_initialize_by(github_event_id: github_event_id)
    return record unless record.new_record?

    record.assign_attributes(
      raw_payload: event_hash,
      repository_github_id: repo["id"],
      push_id: payload["push_id"],
      ref: payload["ref"],
      head: payload["head"],
      before: payload["before"],
      github_created_at: event_hash["created_at"],
      enrichment_status: "pending"
    )
    record.save!
    record
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    find_by!(github_event_id: github_event_id)
  end

end
