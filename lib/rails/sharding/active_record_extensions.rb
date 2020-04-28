
module Rails::Sharding
  module ActiveRecordExtensions
    # Will automatically add the #using_shard method to all ActiveRecord scopes
    # (including has_many and habtm relations).
    #
    # Despite the fact that the #using_shard method will exist for all scopes, it
    # will only have effect when loading/saving models that include the
    # Rails::Sharding::Shardable module
    def self.extend_active_record_scope
      # avoinds duplicate extension
      return if ActiveRecord::Base.respond_to? :using_shard

      # Includes #using_shard in ActiveRecord::Base models (both classes and instances)
      ActiveRecord::Base.extend ScopeMethods
      ActiveRecord::Base.include ScopeMethods
      ActiveRecord::Base.extend CaseFixer

      # Includes #using_shard scope method in scopes
      ActiveRecord::Relation.include ScopeMethods
      ActiveRecord::Relation.extend CaseFixer

      # Includes #using_shard scope method in has_many and habtm relations
      ActiveRecord::Scoping.include ScopeMethods
      ActiveRecord::Scoping.extend CaseFixer
    end

    module ScopeMethods
      def using_shard(shard_group, shard_name)
        if block_given?
          raise Errors::WrongUsageError,
            "#{name}.using is not allowed to receive a block, it works just like a regular scope.\nIf you are trying to scope everything to a specific shard, use Shards::Core.using_shard instead."
        end

        ScopeProxy.new(shard_group, shard_name, self)
      end
    end

    # Return value of the #using_shard scope method. Allows us to chain the shard
    # choice with other ActiveRecord scopes
    class ScopeProxy
      attr_accessor :original_scope

      def initialize(shard_group, shard_name, original_scope)
        @shard_group = shard_group
        @shard_name = shard_name
        @original_scope = original_scope
      end

      # if using_shard is called twice in a chain, just replaces configuration
      def using_shard(shard_group, shard_name)
        @shard_group = shard_group
        @shard_name = shard_name
        self
      end

      def method_missing(method, *args, &block)
        # runs any method chained in the correct shard
        result = Core.using_shard(@shard_group, @shard_name) do
          @original_scope.send(method, *args, &block)
        end

        # if result is still a scope (responds to to_sql), update original scope
        # and return proxy to continue chaining
        if result.respond_to?(:to_sql)
          @original_scope = result
          return self
        end

        result
      end

      # Delegates == to method_missing so that User.using_scope(:a,:b).where(:name => "Mike")
      # gets run in the correct shard context when #== is evaluated.
      def ==(other)
        method_missing(:==, other)
      end
      alias_method :eql?, :==
    end

    # Fixes case-when behavior when ScopeProxy is passed to case
    # (otherwise classes don't match)
    module CaseFixer
      def ===(other)
        other = other.original_scope while other === ScopeProxy
        super
      end
    end
  end
end
