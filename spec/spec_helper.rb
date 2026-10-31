require 'core_mcp'
require 'rspec/expectations'
require 'capybara/playwright'
require 'capybara/rspec'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |path| require path }

RSpec.configure do |config|
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.disable_monkey_patching!
  config.include_context 'with MCP configuration'
end
