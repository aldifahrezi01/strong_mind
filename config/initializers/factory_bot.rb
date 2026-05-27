if defined?(FactoryBot)
  FactoryBot.definition_file_paths = [Rails.root.join("spec/factories")]
  FactoryBot.find_definitions unless FactoryBot.factories.any?
end
