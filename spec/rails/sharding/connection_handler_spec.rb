require 'spec_helper'

describe Rails::Sharding::ConnectionHandler do

  before do
    @mock_connection_handler = instance_double(ActiveRecord::ConnectionAdapters::ConnectionHandler)
    allow(Rails::Sharding::ConnectionHandler).to receive(:connection_handler).and_return(@mock_connection_handler)
  end

  describe '.establish_connection' do
    it 'should raise error if shards.yml does not define configuration for current rails env' do
      expect do
        described_class.establish_connection(:shard_group1, :shard, 'fake_environment')
      end.to raise_error Rails::Sharding::Errors::ConfigNotFoundError
    end

    it 'should raise error if shards.yml does not define configuration for shard_group' do
      expect do
        described_class.establish_connection(:fake_shard_group, :shard)
      end.to raise_error Rails::Sharding::Errors::ConfigNotFoundError
    end

    it 'should raise error if shards.yml does not define configuration for shard' do
      expect do
        described_class.establish_connection(:shard_group1, :fake_shard)
      end.to raise_error Rails::Sharding::Errors::ConfigNotFoundError
    end

    it 'should establish connection through a ActiveRecord::AbstractAdapters::ConnectionHandler' do
      expect(@mock_connection_handler).to receive(:establish_connection).once do |connection_owner, connection_spec|
        expect(connection_owner).to be_a Rails::Sharding::ConnectionHandler::ConnectionPoolOwner
        expect(connection_owner.name).to be == 'shard_group1:shard1'

        expect(connection_spec).to be_a ActiveRecord::ConnectionAdapters::ConnectionSpecification
        expect(connection_spec.config).to include(:adapter=>"mysql2", :encoding=>"utf8", :reconnect=>false, :pool=>5, :socket=>"/var/run/mysqld/mysqld.sock", :database=>"group1_shard1_development")
      end

      described_class.establish_connection(:shard_group1, :shard1)
    end
  end

  describe '.establish_all_connections' do
    it 'should establish connections for all shards for the current environment' do
      expect(@mock_connection_handler).to receive(:establish_connection).once do |connection_owner, connection_spec|
        expect(connection_owner.name).to be == 'shard_group1:shard1'
      end
      expect(@mock_connection_handler).to receive(:establish_connection).once do |connection_owner, connection_spec|
        expect(connection_owner.name).to be == 'shard_group1:shard2'
      end

      described_class.establish_all_connections
    end
  end

  describe '.connection_pool' do
    it 'should retrieve connection pool from the connection handler' do
      expect(@mock_connection_handler).to receive(:retrieve_connection_pool).once do |connection_owner|
        expect(connection_owner.name).to be == 'shard_group1:shard1'
      end

      described_class.connection_pool(:shard_group1, :shard1)
    end

    it 'should raise a ActiveRecord::ConnectionNotEstablished if pool doesnt exist' do
      # pass the call to a real connection handler
      expect(@mock_connection_handler).to receive(:retrieve_connection_pool).once do |connection_owner|
        ActiveRecord::ConnectionAdapters::ConnectionHandler.new.retrieve_connection_pool(connection_owner)
      end

      expect do
        described_class.connection_pool(:shard_group1, :fake_shard)
      end.to raise_error ActiveRecord::ConnectionNotEstablished
    end
  end

  describe '.retrieve_connection' do
    it 'should retrieve connection from the connection handler' do
      expect(@mock_connection_handler).to receive(:retrieve_connection).once do |connection_owner|
        expect(connection_owner.name).to be == 'shard_group1:shard1'
      end

      described_class.retrieve_connection(:shard_group1, :shard1)
    end
  end

  describe '.connected?' do
    it 'should check connection through the connection handler' do
      expect(@mock_connection_handler).to receive(:connected?).once do |connection_owner|
        expect(connection_owner.name).to be == 'shard_group1:shard1'
      end

      described_class.connected?(:shard_group1, :shard1)
    end
  end

  describe '.with_connection' do
    it 'should yield a connection got from the connection handler to a block' do
      mock_connection_pool = double('connection_pool')
      expect(@mock_connection_handler).to receive(:retrieve_connection_pool).once do |connection_owner|
        expect(connection_owner.name).to be == 'shard_group1:shard1'
      end.and_return(mock_connection_pool)

      mock_connection = double('connection')
      expect(mock_connection_pool).to receive(:with_connection).once do |&block|
        block.call mock_connection
      end

      described_class.with_connection(:shard_group1, :shard1) do |connection|
        expect(connection).to be == mock_connection
      end
    end
  end

  describe '.remove_connection' do
    it 'should remove connection through the connection handler' do
      expect(@mock_connection_handler).to receive(:remove_connection).once do |connection_owner|
        expect(connection_owner.name).to be == 'shard_group1:shard1'
      end

      described_class.remove_connection(:shard_group1, :shard1)
    end
  end

end
