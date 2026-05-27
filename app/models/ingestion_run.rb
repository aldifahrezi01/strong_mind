class IngestionRun < ApplicationRecord
  STATUSES = %w[running completed failed rate_limited].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true

  def complete!(status: "completed", error_message: nil)
    update!(
      status: status,
      error_message: error_message,
      finished_at: Time.current
    )
  end
end
