class HealthController < ApplicationController
  def show
    render json: {
      status: "ok",
      database: database_connected?,
      push_events_count: PushEvent.count,
      last_ingestion_run: last_run_summary
    }
  end

  private

  def database_connected?
    ActiveRecord::Base.connection.active?
  rescue StandardError
    false
  end

  def last_run_summary
    run = IngestionRun.order(started_at: :desc).first
    return nil unless run

    {
      id: run.id,
      status: run.status,
      started_at: run.started_at,
      finished_at: run.finished_at,
      push_events_persisted: run.push_events_persisted
    }
  end
end
