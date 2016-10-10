require 'rails/sharding/active_record_extensions'
require 'rails/sharding/config'
require 'rails/sharding/connection_handler'
require 'rails/sharding/errors'
require 'rails/sharding/shard_thread_registry'
require 'rails/sharding/shardable_model'

module Rails::Sharding
  class Core

    # Opens a block where all queries will be directed to the selected shard
    def self.using_shard(shard_group, shard_name)
      raise 'Cannot nest using_shard blocks' if ShardThreadRegistry.connecting_to_shard?

      ShardThreadRegistry.current_shard_group = shard_group
      ShardThreadRegistry.current_shard_name = shard_name
      ShardThreadRegistry.shard_connection_used = false
      yield
    ensure
      # shows warning to user
      if !ShardThreadRegistry.shard_connection_used
        puts "Warning: no connection to shard '#{ShardThreadRegistry.current_shard_group}:#{ShardThreadRegistry.current_shard_name}' was made inside the using_shard block. Make sure you don't forget to include Rails::Sharding::ShardableModel to the models you want to be sharded"
      end

      # Releases connections in case user left some connection in the reserved state
      # (by calling retrieve_connection instead of with_connection). Also, using
      # normal activerecord queries leaves a connection in the reserved state
      ConnectionHandler.connection_pool(*ShardThreadRegistry.current_shard_group_and_name).release_connection
      ShardThreadRegistry.connect_back_to_master!
    end

    def self.configurations(environment=Rails.env)
      @@db_configs ||= YAML.load_file(Config.shards_config_file)
      @@db_configs[environment]
    rescue Errno::ENOENT
      raise Errors::ConfigNotFoundError, Config.shards_config_file.to_s + ' file was not found'
    end

    def self.reset_configurations_cache
      @@db_configs = nil
    end

    def self.test_configurations
      self.configurations('test')
    end

    def self.shard_groups
      self.configurations.keys
    end

    def self.shard_names(shard_group)
      self.configurations[shard_group.to_s].keys
    end

    # yields a block for each shard in each shard group, with its configurations
    # shard_group_filter: if passed yields only shards of this group
    # shard_name_filter: if passed yields only shards with this name
    def self.for_each_shard(shard_group_filter=nil, shard_name_filter=nil)
      shard_group_filter.to_s if shard_group_filter
      shard_name_filter.to_s if shard_name_filter

      configurations.each do |shard_group, shards_configurations|
        next if shard_group_filter && shard_group_filter != shard_group.to_s

        shards_configurations.each do |shard, configuration|
          next if shard_name_filter && shard_name_filter != shard.to_s
          yield shard_group, shard, configuration
        end
      end
    end

    # Method that should be called on a rails initializer
    def self.setup
      if block_given?
        yield Config
      end

      if Config.establish_all_connections_on_setup
        # Establishes connections with all shards specified in config/shards.yml
        ConnectionHandler.establish_all_connections
      end

      if Config.extend_active_record_scope
        # includes the #using_shard method to all AR scopes
        ActiveRecordExtensions.extend_active_record_scope
      end
    end

  end
end
