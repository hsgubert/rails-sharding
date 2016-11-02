# Adds code climate test reporter. To activate it, set the CODECLIMATE_REPO_TOKEN environment variable
if ENV['CODECLIMATE_REPO_TOKEN']
  require "codeclimate-test-reporter"
  CodeClimate::TestReporter.start
elsif ENV['SIMPLECOV']
  require 'simplecov'
  SimpleCov.start
end

require 'load_gem_test_env'

RSpec.configure do |config|
  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # includes custom test helpers
  require 'support/test_helpers'
  config.include Support::TestHelpers
end
