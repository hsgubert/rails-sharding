require 'spec_helper'

describe Rails::Sharding::ShardableModel do

  class TestModel < ActiveRecord::Base
    include Rails::Sharding::ShardableModel
  end

  before do
    # because we try to release the connection everytime a usign_shard block ends
    mock_connection_pool = instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool)
    allow(mock_connection_pool).to receive(:release_connection)
    allow(Rails::Sharding::ConnectionHandler).to receive(:connection_pool).and_return(mock_connection_pool)

    # because some methods like clear_active_connections! are called on the
    # ActiveRecord::AbstractAdapters::ConnectionHandler
    @mock_connection_handler = instance_double(ActiveRecord::ConnectionAdapters::ConnectionHandler)
    allow(Rails::Sharding::ConnectionHandler).to receive(:connection_handler).and_return(@mock_connection_handler)
  end

  describe '.connection_pool' do
    it 'should call original method if connecting to master' do
      expect(TestModel).to receive(:original_connection_pool).once
      TestModel.connection_pool
    end

    it 'should retrive sharded connection_pool if using shard' do
      expect(Rails::Sharding::ConnectionHandler).to receive(:connection_pool).twice.with(:mysql_group, :shard1)
      Rails::Sharding.using_shard(:mysql_group, :shard1) do
        TestModel.connection_pool
      end
    end
  end

  describe '.retrieve_connection' do
    it 'should call original method if connecting to master' do
      expect(TestModel).to receive(:original_retrieve_connection).once
      TestModel.retrieve_connection
    end

    it 'should delegate to sharded retrieve_connection if using shard' do
      expect(Rails::Sharding::ConnectionHandler).to receive(:retrieve_connection).once.with(:mysql_group, :shard1)
      Rails::Sharding.using_shard(:mysql_group, :shard1) do
        TestModel.retrieve_connection
      end
    end
  end

  describe '.connected?' do
    it 'should call original method if connecting to master' do
      expect(TestModel).to receive(:original_connected?).once
      TestModel.connected?
    end

    it 'should delegate to sharded connected? if using shard' do
      expect(Rails::Sharding::ConnectionHandler).to receive(:connected?).once.with(:mysql_group, :shard1)
      Rails::Sharding.using_shard(:mysql_group, :shard1) do
        TestModel.connected?
      end
    end
  end

  describe '.remove_connection' do
    it 'should call original method if connecting to master' do
      expect(TestModel).to receive(:original_remove_connection).once
      TestModel.remove_connection
    end

    it 'should delegate to sharded retrieve_connection if using shard' do
      expect(Rails::Sharding::ConnectionHandler).to receive(:remove_connection).once.with(:mysql_group, :shard1)
      Rails::Sharding.using_shard(:mysql_group, :shard1) do
        TestModel.remove_connection
      end
    end

    it 'should call original method if call includes a specific class as parameter' do
      expect(TestModel).to receive(:original_remove_connection).once
      Rails::Sharding.using_shard(:mysql_group, :shard1) do
        TestModel.remove_connection(TestModel)
      end
    end
  end

  describe '.establish_connection' do
    it 'should call original method if connecting to master' do
      expect(TestModel).to receive(:original_establish_connection).once
      TestModel.establish_connection
    end

    it 'should pass spec to original method if connecting to master' do
      expect(TestModel).to receive(:original_establish_connection).with({custom_spec: true}).once
      TestModel.establish_connection({custom_spec: true})
    end

    it 'should delegate to sharded establish_connection if using shard' do
      expect(Rails::Sharding::ConnectionHandler).to receive(:establish_connection).once.with(:mysql_group, :shard1)
      Rails::Sharding.using_shard(:mysql_group, :shard1) do
        TestModel.establish_connection
      end
    end
  end

  describe '.clear_active_connections!' do
    it 'should call original method if connecting to master' do
      expect(TestModel).to receive(:original_clear_active_connections!).once
      TestModel.clear_active_connections!
    end

    it 'should delegate to sharded clear_active_connections! if using shard' do
      expect(@mock_connection_handler).to receive(:clear_active_connections!).once
      Rails::Sharding.using_shard(:mysql_group, :shard1) do
        TestModel.clear_active_connections!
      end
    end
  end

  describe '.clear_reloadable_connections!' do
    it 'should call original method if connecting to master' do
      expect(TestModel).to receive(:original_clear_reloadable_connections!).once
      TestModel.clear_reloadable_connections!
    end

    it 'should delegate to sharded clear_reloadable_connections! if using shard' do
      expect(@mock_connection_handler).to receive(:clear_reloadable_connections!).once
      Rails::Sharding.using_shard(:mysql_group, :shard1) do
        TestModel.clear_reloadable_connections!
      end
    end
  end

  describe '.clear_all_connections!' do
    it 'should call original method if connecting to master' do
      expect(TestModel).to receive(:original_clear_all_connections!).once
      TestModel.clear_all_connections!
    end

    it 'should delegate to sharded clear_all_connections! if using shard' do
      expect(@mock_connection_handler).to receive(:clear_all_connections!).once
      Rails::Sharding.using_shard(:mysql_group, :shard1) do
        TestModel.clear_all_connections!
      end
    end
  end

end
