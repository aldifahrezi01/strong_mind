class CreateGithubRepositories < ActiveRecord::Migration[7.2]
  def change
    create_table :github_repositories do |t|
      t.bigint :github_id, null: false
      t.string :full_name, null: false
      t.string :api_url, null: false
      t.jsonb :raw_payload, null: false, default: {}
      t.datetime :fetched_at, null: false

      t.timestamps
    end

    add_index :github_repositories, :github_id, unique: true
    add_index :github_repositories, :api_url, unique: true
    add_index :github_repositories, :full_name
  end
end
