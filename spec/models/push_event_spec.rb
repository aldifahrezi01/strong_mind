require "rails_helper"

RSpec.describe PushEvent, type: :model do
  describe ".upsert_from_github_event!" do
    let(:event) do
      JSON.parse(File.read(Rails.root.join("spec/fixtures/github_events.json"))).find do |e|
        e["type"] == "PushEvent"
      end
    end

    it "persists structured push fields and raw payload" do
      record = described_class.upsert_from_github_event!(event)

      expect(record).to be_persisted
      expect(record.github_event_id).to eq("98765432109")
      expect(record.repository_github_id).to eq(1_296_269)
      expect(record.push_id).to eq(105_249_413)
      expect(record.ref).to eq("refs/heads/master")
      expect(record.head).to eq("b1e8c6fea7d304f4f7b8ba655d6a58ff8c90eb72")
      expect(record.before).to eq("0d1d07e32b040733ebdc8ab87819237ee2e21030")
      expect(record.raw_payload["type"]).to eq("PushEvent")
    end

    it "is idempotent for duplicate github event ids" do
      first = described_class.upsert_from_github_event!(event)
      second = described_class.upsert_from_github_event!(event)

      expect(second.id).to eq(first.id)
      expect(described_class.count).to eq(1)
    end

    it "ignores non-push events" do
      watch = JSON.parse(File.read(Rails.root.join("spec/fixtures/github_events.json"))).first
      expect(described_class.upsert_from_github_event!(watch)).to be_nil
    end
  end
end
