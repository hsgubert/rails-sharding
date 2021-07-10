require 'active_support/core_ext/module'

module Rails::Sharding
  class ShardThreadRegistry
    # Creates two thread-specific stacks to store the shard of connection
    # The top of the stack indicates the current connection
    # This allows us to have nested blocks of #using_shard and keep track of the
    # connections as we open/close those blocks
    thread_mattr_accessor :_shard_group_stack
    thread_mattr_accessor :_shard_name_stack

    # auxiliary stack that keeps track of wether each shard connection was used
    # inside its respective using_shard block (so we can print an alert if not)
    thread_mattr_accessor :_shard_connection_used_stack

    # accessors that initialize stacks if necessary
    def self.shard_group_stack; self._shard_group_stack ||= [] end;
    def self.shard_name_stack; self._shard_name_stack ||= [] end;
    def self.shard_connection_used_stack; self._shard_connection_used_stack ||= [] end;

    def self.connecting_to_master?
      current_shard_group.nil? || current_shard_name.nil?
    end

    def self.connecting_to_shard?
      !connecting_to_master?
    end

    # Clears the connection stack and goes back to connecting to master
    def self.connect_back_to_master!
      shard_group_stack.clear
      shard_name_stack.clear
      shard_connection_used_stack.clear
    end

    # Returns the current shard group (for the current Thread)
    def self.current_shard_group
      shard_group_stack.last
    end

    # Returns the current shard name (for the current Thread)
    def self.current_shard_name
      shard_name_stack.last
    end

    def self.current_connection_used?
      shard_connection_used_stack.last
    end

    # adds shard connection to the stack
    def self.push_current_shard(group, name)
      # this line supresses the unused connection warning when there are nested
      # using_shard blocks. We suppress the warning because we view nested using_shard
      # blocks as a override
      notify_connection_retrieved

      shard_group_stack.push(group.blank? ? nil : group.to_sym)
      shard_name_stack.push(name.blank? ? nil : name.to_sym)
      shard_connection_used_stack.push(false)
    end

    # notifies the current connection was used (wee keep track of this to warn
    # the user in case the connection is not used)
    def self.notify_connection_retrieved
      shard_connection_used_stack[-1] = true if shard_connection_used_stack.present?
    end

    # removes shard connection to the stack
    def self.pop_current_shard
      [shard_group_stack.pop, shard_name_stack.pop, shard_connection_used_stack.pop]
    end

    def self.current_shard_group_and_name
      [current_shard_group, current_shard_name]
    end

  end
end
