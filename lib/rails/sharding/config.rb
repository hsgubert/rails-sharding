module Rails::Sharding
  class Config
    DEFAULT_CONFIGS = {
      # If true one connection will be established per shard (in every shard group)
      # on startup. This only establishes the connection with the database but
      # it does not retrieve a connection yet. This will be done by the ConnectionPool
      # when necessary.
      # If false the user must call Shards::ConnectionHandler.establish_connection(shard_group, shard_name)
      # manually at least once before using each shard.
      establish_all_connections_on_setup: true,

      # If true the method #using_shard will be mixed in ActiveRecord scopes. Put
      # this to false if you don't want the gem to modify ActiveRecord
      extend_active_record_scope: true,

      # If true the query logs of ActiveRecord will be tagged with the corresponding
      # shard you're querying
      add_shard_tag_to_query_logs: true,

      # If true a warning will be printed everytime a using_shard block ends without
      # the shard connection being retrieved at least once inside the block. This warning
      # is helpful to remember the developer to include ShardableModel module on the
      # sharded models, otherwise they will always connect to the master database.
      no_connection_retrieved_warning: true,

      # Specifies where to find the definition of the shards configurations
      shards_config_file: 'config/shards.yml',

      # Specifies where to find the migrations for each shard group
      shards_migrations_dir: 'db/shards_migrations',

      # Specifies where to find the schemas for each shard group
      shards_schemas_dir: 'db/shards_schemas'
    }

    DEFAULT_CONFIGS.each do |config_name, default_value|
      self.cattr_accessor config_name
      self.send(config_name.to_s + '=', default_value)
    end
  end
end
