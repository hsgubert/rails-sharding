# This file load the enviroment to run the gem tests. It is called from the
# spec_helper (to run tests) and also from the Rakefile (to prepare test
# databases).
#
# Preparing the test enviroment includes:
# => Setting up the load path to find files in the lib directory
# => Loading rails
# => Changing default rails-sharding config files paths to paths in spec/fixtures
# => Setting up rails-sharding
#
# After this setup your environment will be just like a rails app with
# RAILS_ENV=development that includes and initializes the rails-sharding gem

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

# requires rails, as the gem depends on it, and sets the RAILS_ENV to development
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

# checks if shards.yml exists for tests to give a friendlier error message
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

# Setups rails-sharding, establishing connection to test databases
Rails::Sharding.setup do |config|
  config.no_connection_retrieved_warning = false
end
$rails_sharding_configs_changed = [:no_connection_retrieved_warning]
