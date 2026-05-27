require "spec_helper"
require "rspec/rails"
require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.include FactoryBot::Syntax::Methods
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
