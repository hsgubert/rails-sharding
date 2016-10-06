module Rails::Sharding
  class ConnectionHandler

    # Establishes connections to all shards in all shard groups.
    # Despite the name, this actually only creates a connection pool with zero
    # connections for each shard. The connections will be allocated for each
    # thread when #retrieve_connection or #with_connection are called
    def self.establish_all_connections
      Core.shard_groups.each do |shard_group|
        Core.shard_names(shard_group).each do |shard_name|
          establish_connection(shard_group, shard_name)
        end
      end
    end

    # Establishes a connection to a single shard in a single shard group
    def self.establish_connection(shard_group, shard_name, environment=nil)
      self.setup unless defined? @@connection_handler

      unless configurations = (environment.nil? ? Core.configurations : Core.configurations(environment))
        raise Errors::ConfigNotFoundError, "Cannot find configuration for environment '#{environment}' in #{Config.shards_config_file}"
      end

      unless shard_group_configurations = configurations[shard_group.to_s]
        raise Errors::ConfigNotFoundError, "Cannot find configuration for shard_group '#{shard_group}' in environment '#{environment}' in #{Config.shards_config_file}"
      end

      resolver = ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new(shard_group_configurations)
      begin
        connection_spec = resolver.spec(shard_name.to_sym)
      rescue ActiveRecord::AdapterNotSpecified => e
        raise Errors::ConfigNotFoundError, "Cannot find configuration for shard '#{shard_group}:#{shard_name}' in environment '#{environment}' in #{Config.shards_config_file}"
      end

      # since rails requires a class to be the connection owner, we trick rails passing
      # an instance of the ConnectionPoolOwner class, that responds to the #name method
      connection_handler.establish_connection(connection_pool_owner(shard_group, shard_name), connection_spec)
    end

    def self.connection_pool(shard_group, shard_name)
      connection_handler.retrieve_connection_pool(connection_pool_owner(shard_group, shard_name))
    rescue Errors::ConnectionPoolRetrievalError
      # mimicking behavior of rails at:
      # https://github.com/rails/rails/blob/4-2-stable/activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb#507
      raise ActiveRecord::ConnectionNotEstablished, "No connection pool for shard #{connection_name(shard_group, shard_name)}"
    end

    def self.retrieve_connection(shard_group, shard_name)
      connection_handler.retrieve_connection(connection_pool_owner(shard_group, shard_name))
    end

    def self.connected?(shard_group, shard_name)
      connection_handler.connected?(connection_pool_owner(shard_group, shard_name))
    end

    def self.with_connection(shard_group, shard_name, &block)
    	connection_pool(shard_group, shard_name).with_connection(&block)
    end

    def self.remove_connection(shard_group, shard_name)
      connection_handler.remove_connection(connection_pool_owner(shard_group, shard_name))
    end

  private

    def self.connection_handler
      raise Errors::UninitializedError, 'Shards::ConnectionHandler was not setup' unless defined? @@connection_handler
      @@connection_handler
    end

    def self.setup
      @@connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
      @@connection_pool_owners = {}
    end

    def self.connection_pool_owner(shard_group, shard_name)
      connection_name = self.connection_name(shard_group, shard_name)
      @@connection_pool_owners[connection_name] ||= ConnectionPoolOwner.new(connection_name)
    end

    # Assembles connection name in the format "shard_group:shard_name"
    def self.connection_name(shard_group, shard_name)
      shard_group.to_s + ':' + shard_name.to_s
    end

    class ConnectionPoolOwner
      attr_reader :name

      def initialize(name)
      	@name = name
      end

      # Safeguard in case pool cannot be retrieved for owner. This makes the error clear
      def superclass
      	raise Errors::ConnectionPoolRetrievalError, "ConnectionPool could not be retrieved for #{self}. See https://github.com/rails/rails/blob/4-2-stable/activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb#607"
      end

      # in case owner ends up printed by rails in an error message when retrieving connection
      def to_s
        "ConnectionPoolOwner with name #{self.name}"
      end
    end
  end
end
