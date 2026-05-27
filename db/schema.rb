# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2024_05_21_000004) do
  enable_extension "plpgsql"

  create_table "github_actors", force: :cascade do |t|
    t.bigint "github_id", null: false
    t.string "login", null: false
    t.string "api_url", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "fetched_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_url"], name: "index_github_actors_on_api_url", unique: true
    t.index ["github_id"], name: "index_github_actors_on_github_id", unique: true
  end

  create_table "github_repositories", force: :cascade do |t|
    t.bigint "github_id", null: false
    t.string "full_name", null: false
    t.string "api_url", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "fetched_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_url"], name: "index_github_repositories_on_api_url", unique: true
    t.index ["full_name"], name: "index_github_repositories_on_full_name"
    t.index ["github_id"], name: "index_github_repositories_on_github_id", unique: true
  end

  create_table "ingestion_runs", force: :cascade do |t|
    t.string "status", default: "running", null: false
    t.integer "events_fetched", default: 0, null: false
    t.integer "push_events_seen", default: 0, null: false
    t.integer "push_events_persisted", default: 0, null: false
    t.integer "push_events_skipped", default: 0, null: false
    t.integer "enrichments_succeeded", default: 0, null: false
    t.integer "enrichments_failed", default: 0, null: false
    t.text "error_message"
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "push_events", force: :cascade do |t|
    t.string "github_event_id", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.bigint "repository_github_id", null: false
    t.bigint "push_id", null: false
    t.string "ref", null: false
    t.string "head", null: false
    t.string "before", null: false
    t.bigint "github_actor_id"
    t.bigint "github_repository_id"
    t.string "enrichment_status", default: "pending", null: false
    t.text "last_error"
    t.integer "retry_count", default: 0, null: false
    t.datetime "github_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enrichment_status"], name: "index_push_events_on_enrichment_status"
    t.index ["github_actor_id"], name: "index_push_events_on_github_actor_id"
    t.index ["github_created_at"], name: "index_push_events_on_github_created_at"
    t.index ["github_event_id"], name: "index_push_events_on_github_event_id", unique: true
    t.index ["github_repository_id"], name: "index_push_events_on_github_repository_id"
    t.index ["push_id"], name: "index_push_events_on_push_id"
    t.index ["ref"], name: "index_push_events_on_ref"
    t.index ["repository_github_id"], name: "index_push_events_on_repository_github_id"
  end

  add_foreign_key "push_events", "github_actors"
  add_foreign_key "push_events", "github_repositories"
end
