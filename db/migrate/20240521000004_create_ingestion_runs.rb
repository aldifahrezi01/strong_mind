class CreateIngestionRuns < ActiveRecord::Migration[7.2]
  def change
    create_table :ingestion_runs do |t|
      t.string :status, null: false, default: "running"
      t.integer :events_fetched, null: false, default: 0
      t.integer :push_events_seen, null: false, default: 0
      t.integer :push_events_persisted, null: false, default: 0
      t.integer :push_events_skipped, null: false, default: 0
      t.integer :enrichments_succeeded, null: false, default: 0
      t.integer :enrichments_failed, null: false, default: 0
      t.text :error_message
      t.datetime :started_at, null: false
      t.datetime :finished_at

      t.timestamps
    end
  end
end
