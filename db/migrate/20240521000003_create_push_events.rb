class CreatePushEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :push_events do |t|
      t.string :github_event_id, null: false
      t.jsonb :raw_payload, null: false, default: {}

      t.bigint :repository_github_id, null: false
      t.bigint :push_id, null: false
      t.string :ref, null: false
      t.string :head, null: false
      t.string :before, null: false

      t.references :github_actor, foreign_key: true
      t.references :github_repository, foreign_key: true

      t.string :enrichment_status, null: false, default: "pending"
      t.text :last_error
      t.integer :retry_count, null: false, default: 0

      t.datetime :github_created_at
      t.timestamps
    end

    add_index :push_events, :github_event_id, unique: true
    add_index :push_events, :repository_github_id
    add_index :push_events, :push_id
    add_index :push_events, :ref
    add_index :push_events, :enrichment_status
    add_index :push_events, :github_created_at
  end
end
