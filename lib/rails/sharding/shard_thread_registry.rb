
module Rails::Sharding
  class ShardThreadRegistry
    # creates two thread-specific variables to store the current shard of connection
    thread_mattr_accessor :_current_shard_group
    thread_mattr_accessor :_current_shard_name

    # auxiliary variable used to check if shard connectio was used inside an
    # using_shard block (so we can print an alert if not)
    thread_mattr_accessor :shard_connection_used

    def self.connecting_to_master?
      current_shard_group.nil? || current_shard_name.nil?
    end

    def self.connecting_to_shard?
      !connecting_to_master?
    end

    def self.connect_back_to_master!
      self.current_shard_group = nil
      self.current_shard_name = nil
      self.shard_connection_used = false
    end

    # Returns the current shard group (for the current Thread)
    def self.current_shard_group
      _current_shard_group
    end

    # Sets the current shard group (for the current Thread)
    def self.current_shard_group=(group)
      self._current_shard_group = group.blank? ? nil : group.to_sym
    end

    # Returns the current shard name (for the current Thread)
    def self.current_shard_name
      _current_shard_name
    end

    # Sets the current shard name (for the current Thread)
    def self.current_shard_name=(name)
      self._current_shard_name = name.blank? ? nil : name.to_sym
    end

    def self.current_shard_group_and_name
      [current_shard_group, current_shard_name]
    end

  end
end
