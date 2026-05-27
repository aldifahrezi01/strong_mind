class CreateGithubActors < ActiveRecord::Migration[7.2]
  def change
    create_table :github_actors do |t|
      t.bigint :github_id, null: false
      t.string :login, null: false
      t.string :api_url, null: false
      t.jsonb :raw_payload, null: false, default: {}
      t.datetime :fetched_at, null: false

      t.timestamps
    end

    add_index :github_actors, :github_id, unique: true
    add_index :github_actors, :api_url, unique: true
  end
end
