require "active_record"

shards_namespace = namespace :shards do
  task _make_activerecord_base_shardable: [:environment] do
    # Several resources used (like Migrator, SchemaDumper, schema methods)
    # implicitly use ActiveRecord::Base.connection, so we have to make it
    # shardable so we can call using_shard and switch the connection
    ActiveRecord::Base.include(Rails::Sharding::ShardableModel) unless ActiveRecord::Base.ancestors.include? Rails::Sharding::ShardableModel
  end

  desc "Creates database shards (options: RAILS_ENV=x SHARD_GROUP=x SHARD=x)"
  task create: [:environment] do
    Rails::Sharding.configurations.each do |shard_group, shards_configurations|
      next if ENV["SHARD_GROUP"] && ENV["SHARD_GROUP"] != shard_group.to_s

      shards_configurations.each do |shard, configuration|
        next if ENV["SHARD"] && ENV["SHARD"] != shard.to_s
        puts "== Creating shard #{shard_group}:#{shard}"
        ActiveRecord::Tasks::DatabaseTasks.create(configuration)
      end
    end
  end

  desc "Drops database shards (options: RAILS_ENV=x SHARD_GROUP=x SHARD=x)"
  task drop: [:environment] do
    Rails::Sharding.configurations.each do |shard_group, shards_configurations|
      next if ENV["SHARD_GROUP"] && ENV["SHARD_GROUP"] != shard_group.to_s

      shards_configurations.each do |shard, configuration|
        next if ENV["SHARD"] && ENV["SHARD"] != shard.to_s
        puts "== Dropping shard #{shard_group}:#{shard}"
        ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
      end
    end
  end

  desc "Migrate the database (options: RAILS_ENV=x, SHARD_GROUP=x, VERSION=x, VERBOSE=false, SCOPE=blog)."
  task migrate: [:_make_activerecord_base_shardable] do
    Rails::Sharding.configurations.each do |shard_group, shards_configurations|
      next if ENV["SHARD_GROUP"] && ENV["SHARD_GROUP"] != shard_group.to_s

      # configures path for migrations of this shard group and creates dir if necessary
      shard_group_migrations_dir = File.join(Rails::Sharding::Config.shards_migrations_dir, shard_group.to_s)
      ActiveRecord::Tasks::DatabaseTasks.migrations_paths = shard_group_migrations_dir
      FileUtils.mkdir_p(shard_group_migrations_dir)

      shards_configurations.each do |shard, configuration|
        next if ENV["SHARD"] && ENV["SHARD"] != shard.to_s
        puts "== Migrating shard #{shard_group}:#{shard}"
        Rails::Sharding.using_shard(shard_group, shard) do
          ActiveRecord::Tasks::DatabaseTasks.migrate
        end
      end
    end

    shards_namespace["_dump"].invoke
  end

  # IMPORTANT: This task won't dump the schema if ActiveRecord::Base.dump_schema_after_migration is set to false
  task :_dump do
    if ActiveRecord::Base.dump_schema_after_migration
      case ActiveRecord::Base.schema_format
      when :ruby
        shards_namespace["schema:dump"].invoke
      when :sql
        raise "sql schema dump not supported by shards"
      else
        raise "unknown schema format #{ActiveRecord::Base.schema_format}"
      end
    end
    # Allow this task to be called as many times as required. An example is the
    # migrate:redo task, which calls other two internally that depend on this one.
    shards_namespace["_dump"].reenable
  end

  namespace :schema do
    desc "Creates a schema.rb for each shard that is portable against any DB supported by Active Record (options: RAILS_ENV=x, SHARD_GROUP=x, SHARD=x)"
    task dump: [:_make_activerecord_base_shardable] do
      require "active_record/schema_dumper"

      Rails::Sharding.configurations.each do |shard_group, shards_configurations|
        next if ENV["SHARD_GROUP"] && ENV["SHARD_GROUP"] != shard_group.to_s

        shards_configurations.each do |shard, configuration|
          next if ENV["SHARD"] && ENV["SHARD"] != shard.to_s
          puts "== Dumping schema of #{shard_group}:#{shard}"

          schema_filename = shard_schema_path(shard_group, shard)
          File.open(schema_filename, "w:utf-8") do |file|
            Rails::Sharding.using_shard(shard_group, shard) do
              ActiveRecord::SchemaDumper.dump(Rails::Sharding::ConnectionHandler.retrieve_connection(shard_group, shard), file)
            end
          end
        end
      end

      # Allow this task to be called as many times as required. An example is the
      # migrate:redo task, which calls other two internally that depend on this one.
      shards_namespace["schema:dump"].reenable
    end

    desc "Loads schema.rb file into the shards (options: RAILS_ENV=x, SHARD_GROUP=x, SHARD=x)"
    task load: [:_make_activerecord_base_shardable] do
      Rails::Sharding.configurations.each do |shard_group, shards_configurations|
        next if ENV["SHARD_GROUP"] && ENV["SHARD_GROUP"] != shard_group.to_s

        setup_migrations_path(shard_group)

        shards_configurations.each do |shard, configuration|
          next if ENV["SHARD"] && ENV["SHARD"] != shard.to_s
          puts "== Loading schema of #{shard_group}:#{shard}"

          schema_filename = shard_schema_path(shard_group, shard)
          ActiveRecord::Tasks::DatabaseTasks.check_schema_file(schema_filename)
          Rails::Sharding.using_shard(shard_group, shard) do
            load(schema_filename)
          end
        end
      end
    end

    task load_if_ruby: ["shards:create", :environment] do
      shards_namespace["schema:load"].invoke if ActiveRecord::Base.schema_format == :ruby
    end
  end

  namespace :migrate do
    desc  'Rollbacks the shards one migration and re migrate up (options: RAILS_ENV=x, VERSION=x, STEP=x, SHARD_GROUP=x, SHARD=x).'
    task redo: [:environment] do
      if ENV["VERSION"]
        shards_namespace["migrate:down"].invoke
        shards_namespace["migrate:up"].invoke
      else
        shards_namespace["rollback"].invoke
        shards_namespace["migrate"].invoke
      end
    end

    desc 'Resets your shards using your migrations for the current environment'
    task reset: ["shards:drop", "shards:create", "shards:migrate"]

    desc 'Runs the "up" for a given migration VERSION.'
    task up: [:_make_activerecord_base_shardable] do
      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless version

      Rails::Sharding.configurations.each do |shard_group, shards_configurations|
        next if ENV["SHARD_GROUP"] && ENV["SHARD_GROUP"] != shard_group.to_s

        setup_migrations_path(shard_group)

        shards_configurations.each do |shard, configuration|
          next if ENV["SHARD"] && ENV["SHARD"] != shard.to_s
          puts "== Migrating up shard #{shard_group}:#{shard}"
          Rails::Sharding.using_shard(shard_group, shard) do
            ActiveRecord::Migrator.run(:up, ActiveRecord::Tasks::DatabaseTasks.migrations_paths, version)
          end
        end
      end

      shards_namespace["_dump"].invoke
    end

    desc 'Runs the "down" for a given migration VERSION.'
    task down: [:_make_activerecord_base_shardable] do
      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required - To go down one migration, run db:rollback" unless version

      Rails::Sharding.configurations.each do |shard_group, shards_configurations|
        next if ENV["SHARD_GROUP"] && ENV["SHARD_GROUP"] != shard_group.to_s

        setup_migrations_path(shard_group)

        shards_configurations.each do |shard, configuration|
          next if ENV["SHARD"] && ENV["SHARD"] != shard.to_s
          puts "== Migrating down shard #{shard_group}:#{shard}"
          Rails::Sharding.using_shard(shard_group, shard) do
            ActiveRecord::Migrator.run(:down, ActiveRecord::Tasks::DatabaseTasks.migrations_paths, version)
          end
        end
      end

      shards_namespace["_dump"].invoke
    end
  end

  desc "Rolls the schema back to the previous version (options: RAILS_ENV=x, STEP=x, SHARD_GROUP=x, SHARD=x)."
  task rollback: [:_make_activerecord_base_shardable] do
    step = ENV["STEP"] ? ENV["STEP"].to_i : 1
    Rails::Sharding.configurations.each do |shard_group, shards_configurations|
      next if ENV["SHARD_GROUP"] && ENV["SHARD_GROUP"] != shard_group.to_s

      setup_migrations_path(shard_group)

      shards_configurations.each do |shard, configuration|
        next if ENV["SHARD"] && ENV["SHARD"] != shard.to_s
        puts "== Rolling back shard #{shard_group}:#{shard}"
        Rails::Sharding.using_shard(shard_group, shard) do
          ActiveRecord::Migrator.rollback(ActiveRecord::Tasks::DatabaseTasks.migrations_paths, step)
        end
      end
    end

    shards_namespace["_dump"].invoke
  end

  desc "Retrieves the current schema version number"
  task version: [:_make_activerecord_base_shardable] do
    Rails::Sharding.configurations.each do |shard_group, shards_configurations|
      next if ENV["SHARD_GROUP"] && ENV["SHARD_GROUP"] != shard_group.to_s

      shards_configurations.each do |shard, configuration|
        next if ENV["SHARD"] && ENV["SHARD"] != shard.to_s

        Rails::Sharding.using_shard(shard_group, shard) do
          puts "Shard #{shard_group}:#{shard} version: #{ActiveRecord::Migrator.current_version}"
        end
      end
    end
  end


  namespace :test do
    desc "Recreate the test shards from existent schema files (options: SHARD_GROUP=x, SHARD=x)"
    task load_schema: ['shards:test:purge'] do
      Rails::Sharding.test_configurations.each do |shard_group, shards_configurations|
        next if ENV["SHARD_GROUP"] && ENV["SHARD_GROUP"] != shard_group.to_s

        setup_migrations_path(shard_group)

        shards_configurations.each do |shard, configuration|
          next if ENV["SHARD"] && ENV["SHARD"] != shard.to_s

          puts "== Loading test schema on shard #{shard_group}:#{shard}"
          begin
            # establishes connection with test shard, saving if it was connected before
            should_reconnect = Rails::Sharding::ConnectionHandler.connection_pool(shard_group, shard).active_connection?
            Rails::Sharding::ConnectionHandler.establish_connection(shard_group, shard, 'test')

            schema_filename = shard_schema_path(shard_group, shard)
            ActiveRecord::Tasks::DatabaseTasks.check_schema_file(schema_filename)
            Rails::Sharding.using_shard(shard_group, shard) do
              ActiveRecord::Schema.verbose = false
              load(schema_filename)
            end
          ensure
            if should_reconnect
              # reestablishes connection for RAILS_ENV environment (whatever that is)
              Rails::Sharding::ConnectionHandler.establish_connection(shard_group, shard)
            end
          end
        end
      end
    end

    desc 'Load the test schema into the shards (options: SHARD_GROUP=x, SHARD=x)'
    task prepare: [:environment] do
      unless Rails::Sharding.test_configurations.blank?
        shards_namespace["test:load_schema"].invoke
      end
    end

    desc "Empty the test shards (drops all tables) (options: SHARD_GROUP=x, SHARD=x)"
    task :purge => [:_make_activerecord_base_shardable] do
      Rails::Sharding.test_configurations.each do |shard_group, shards_configurations|
        next if ENV["SHARD_GROUP"] && ENV["SHARD_GROUP"] != shard_group.to_s

        shards_configurations.each do |shard, configuration|
          next if ENV["SHARD"] && ENV["SHARD"] != shard.to_s

          puts "== Purging test shard #{shard_group}:#{shard}"
          begin
            # establishes connection with test shard, saving if it was connected before (rails 4.2 doesn't do this, but should)
            should_reconnect = Rails::Sharding::ConnectionHandler.connection_pool(shard_group, shard).active_connection?
            Rails::Sharding::ConnectionHandler.establish_connection(shard_group, shard, 'test')

            Rails::Sharding.using_shard(shard_group, shard) do
              ActiveRecord::Tasks::DatabaseTasks.purge(configuration)
            end
          ensure
            if should_reconnect
              # reestablishes connection for RAILS_ENV environment (whatever that is)
              Rails::Sharding::ConnectionHandler.establish_connection(shard_group, shard)
            end
          end
        end
      end
    end
  end

  # Configures path for migrations of this shard group and creates dir if necessary
  # We need this to run migrations (so we can find them)
  # We need this load schemas (se we can build the schema_migrations table)
  def setup_migrations_path(shard_group)
    shard_group_migrations_dir = File.join(Rails::Sharding::Config.shards_migrations_dir, shard_group.to_s)
    ActiveRecord::Tasks::DatabaseTasks.migrations_paths = [shard_group_migrations_dir]
    ActiveRecord::Migrator.migrations_paths = [shard_group_migrations_dir]
    FileUtils.mkdir_p(shard_group_migrations_dir)
  end

  # configures path for schemas of this shard group and creates dir if necessary
  def shard_schema_path(shard_group, shard_name)
    shard_group_schemas_dir = File.join(Rails::Sharding::Config.shards_schemas_dir, shard_group.to_s)
    FileUtils.mkdir_p(shard_group_schemas_dir)
    File.join(shard_group_schemas_dir, shard_name + "_schema.rb")
  end
end
