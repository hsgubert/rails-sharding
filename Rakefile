require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

# defines an environment task so we can run rake tasks from lib/tasks/rails-sharding.rake.
# The tasks on rails-sharding.rake depend on the :environment task, which is usuallu defined
# by rails. In our case, we just stub it so the rake tasks run
task :environment do
  # do nothing
end

namespace :db do
  namespace :test do

    desc 'Loads gem test environment and rake tasks from gem'
    task :load_env do
      require './spec/load_gem_test_env'
      load 'lib/tasks/rails-sharding.rake'
    end

    desc "Creates database shards for testing the gem"
    task create: [:load_env] do
      # simply calls shards:create as it will work properly after spec_helper
      # changed the shards configuration
      Rake::Task['shards:create'].invoke
    end

    desc "Drops database shards for testing the gem"
    task drop: [:load_env] do
      Rake::Task['shards:drop'].invoke
    end

    desc "Migrates database shards for testing the gem"
    task migrate: [:load_env] do
      Rake::Task['shards:migrate'].invoke
    end

    desc "Prepares database shards for testing the gem (this will clear and recreate database)"
    task prepare: [:load_env] do
      Rake::Task['db:test:drop'].invoke
      Rake::Task['db:test:create'].invoke
      Rake::Task['db:test:migrate'].invoke
    end
  end
end
