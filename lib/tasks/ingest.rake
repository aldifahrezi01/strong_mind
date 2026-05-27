namespace :ingest do
  desc "Run a single GitHub events ingestion cycle"
  task once: :environment do
    Github::IngestionService.new.run_once!
  end

  desc "Continuously ingest GitHub push events"
  task continuous: :environment do
    Github::IngestionService.new.run_continuous!
  end
end
