# Adds code climate test reporter. To activate it, set the CODECLIMATE_REPO_TOKEN environment variable
if ENV['CODECLIMATE_REPO_TOKEN']
  require "codeclimate-test-reporter"
  CodeClimate::TestReporter.start
elsif ENV['SIMPLECOV']
  require 'simplecov'
  SimpleCov.start
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

# requires rails, as the gem depends on it, and sets the RAIL_ENV to development
# (it is not the rails app we are testing, so it is better to test the gem when
# the rails app is not in test env)
require 'rails/all'
ENV['RAILS_ENV'] = 'development'
Rails.env = 'development'

require 'rails/sharding'
require 'byebug'
# Changes location of the config file to a fixture
test_shards_config_path = 'spec/fixtures/shards.yml'
Rails::Sharding::Config::DEFAULT_CONFIGS[:shards_config_file] = test_shards_config_path
Rails::Sharding::Config.shards_config_file = test_shards_config_path

# checks shards.yml exists for tests
unless File.file? test_shards_config_path
  message = "To run tests first create file #{test_shards_config_path} (use the example available at the same directory) then run 'rake db:test:prepare'"
  puts '#######################################################################'
  puts message
  puts '#######################################################################'
  puts ''
  raise message
end

# Changes location of migrations and schemas to a fixture folder
shards_migrations_dir = 'spec/fixtures/migrations'
Rails::Sharding::Config::DEFAULT_CONFIGS[:shards_migrations_dir] = shards_migrations_dir
Rails::Sharding::Config.shards_migrations_dir = shards_migrations_dir
shards_schemas_dir = 'spec/fixtures/schemas'
Rails::Sharding::Config::DEFAULT_CONFIGS[:shards_schemas_dir] = shards_schemas_dir
Rails::Sharding::Config.shards_schemas_dir = shards_schemas_dir


# Setups rails-sharding, establishing connection test databases
Rails::Sharding.setup

RSpec.configure do |config|
  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

end
