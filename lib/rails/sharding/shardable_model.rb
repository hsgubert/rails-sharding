# The purpose of this class is to override ActiveRecord::ConnectionHandling
# methods that access the DB connection or connection pool in any way.
#
# If Rails::Sharding::ShardThreadRegistry.connecting_to_master? is true, we just
# delegate all calls to the original methods of ActiveRecord::ConnectionHandling,
# otherwise we access our own ConnectionHandler and retrieve the connection
# or connection pool to the selected shard

module Rails::Sharding
  module ShardableModel

    def self.included(base)
      # base.extend ClassMethods
      base.extend ClassMethodsOverrides
    end

    # Module that includes all class methods that will be overriden on the model
    # class when Rails::Sharding::ShardableModel is included
    module ClassMethodsOverrides
      # dinamically saves original methods with prefix "original_" and overrides
      # then with the methods with prefix "sharded_"
      def self.extended(klass)
        self.instance_methods.each do |sharded_method_name|
          method_name = sharded_method_name.to_s.match(/sharded_(.+)/)[1].to_sym

          klass.singleton_class.instance_eval do
            alias_method "original_#{method_name}".to_sym, method_name
            alias_method method_name, sharded_method_name
          end
        end
      end

      # @overrides ActiveRecord::ConnectionHandling#connection_pool
      def sharded_connection_pool
        if ShardThreadRegistry.connecting_to_master?
          return original_connection_pool
        else
          ShardThreadRegistry.shard_connection_used = true # records that shard connection was used at least once
          return ConnectionHandler.connection_pool(*ShardThreadRegistry.current_shard_group_and_name)
        end
      end

      # @overrides ActiveRecord::ConnectionHandling#retrieve_connection
      def sharded_retrieve_connection
        if ShardThreadRegistry.connecting_to_master?
          return original_retrieve_connection
        else
          ShardThreadRegistry.shard_connection_used = true # records that shard connection was used at least once
          return ConnectionHandler.retrieve_connection(*ShardThreadRegistry.current_shard_group_and_name)
        end
      end

      # @overrides ActiveRecord::ConnectionHandling#sharded_connected?
      def sharded_connected?
        if ShardThreadRegistry.connecting_to_master?
          return original_connected?
        else
          return ConnectionHandler.connected?(*ShardThreadRegistry.current_shard_group_and_name)
        end
      end

      # @overrides ActiveRecord::ConnectionHandling#remove_connection (only if no parameters are passed)
      def sharded_remove_connection(klass=nil)
        if ShardThreadRegistry.connecting_to_master? || klass
          return klass ? original_remove_connection(klass) : original_remove_connection
        else
          return ConnectionHandler.remove_connection(*ShardThreadRegistry.current_shard_group_and_name)
        end
      end

      # @overrides ActiveRecord::ConnectionHandling#establish_connection
      # In the case we are connecting to a shard, ignore spec parameter and use
      # what is in ShardThreadRegistry instead
      def sharded_establish_connection(spec=nil)
        if ShardThreadRegistry.connecting_to_master?
          return original_establish_connection(spec)
        else
          return ConnectionHandler.establish_connection(*ShardThreadRegistry.current_shard_group_and_name)
        end
      end

      # @overrides ActiveRecord::ConnectionHandling#clear_active_connections!
      def sharded_clear_active_connections!
        if ShardThreadRegistry.connecting_to_master?
          return original_clear_active_connections!
        else
          return ConnectionHandler.connection_handler.clear_active_connections!
        end
      end

      # @overrides ActiveRecord::ConnectionHandling#clear_reloadable_connections!
      def sharded_clear_reloadable_connections!
        if ShardThreadRegistry.connecting_to_master?
          return original_clear_reloadable_connections!
        else
          return ConnectionHandler.connection_handler.clear_reloadable_connections!
        end
      end

      # @overrides ActiveRecord::ConnectionHandling#clear_all_connections!
      def sharded_clear_all_connections!
        if ShardThreadRegistry.connecting_to_master?
          return original_clear_all_connections!
        else
          return ConnectionHandler.connection_handler.clear_all_connections!
        end
      end
    end

  end
end
