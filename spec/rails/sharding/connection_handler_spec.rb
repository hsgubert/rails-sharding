require 'spec_helper'

describe Rails::Sharding::ConnectionHandler do

  # context 'using '


  # This test block allows us to test how methods of Rails::Sharding::ConnectionHandler
  # interact with the ActiveRecord::ConnectionAdapters::ConnectionHandler, which is retrieved
  # through the Rails::Sharding::ConnectionHandler#connection_handler method.
  #
  # We mock #connection_handler so we don't have to worry with the underlying database
  # connections in these tests
  context 'with mocked #connection_handler method' do
    before do
      @mock_connection_handler = instance_double(ActiveRecord::ConnectionAdapters::ConnectionHandler)
      allow(Rails::Sharding::ConnectionHandler).to receive(:connection_handler).and_return(@mock_connection_handler)
    end

    describe '.establish_connection' do
      it 'should raise error if shards.yml does not define configuration for current rails env' do
        expect do
          described_class.establish_connection(:mysql_group, :shard, 'fake_environment')
        end.to raise_error Rails::Sharding::Errors::ConfigNotFoundError
      end

      it 'should raise error if shards.yml does not define configuration for shard_group' do
        expect do
          described_class.establish_connection(:fake_shard_group, :shard)
        end.to raise_error Rails::Sharding::Errors::ConfigNotFoundError
      end

      it 'should raise error if shards.yml does not define configuration for shard' do
        expect do
          described_class.establish_connection(:mysql_group, :fake_shard)
        end.to raise_error Rails::Sharding::Errors::ConfigNotFoundError
      end

      it 'should establish connection through a ActiveRecord::AbstractAdapters::ConnectionHandler' do
        expect(@mock_connection_handler).to receive(:establish_connection).once do |connection_spec|
          expect(connection_spec).to be_a ActiveRecord::ConnectionAdapters::ConnectionSpecification
          expect(connection_spec.name).to be == 'mysql_group:shard1'
          expect(connection_spec.config).to include(:database=>"mysqlgroup_shard1")
        end

        described_class.establish_connection(:mysql_group, :shard1)
      end
    end

    describe '.establish_all_connections' do
      it 'should establish connections for all shards for the current environment' do
        expect(@mock_connection_handler).to receive(:establish_connection).once do |connection_spec|
          expect(connection_spec.name).to be == 'mysql_group:shard1'
        end
        expect(@mock_connection_handler).to receive(:establish_connection).once do |connection_spec|
          expect(connection_spec.name).to be == 'mysql_group:shard2'
        end

        described_class.establish_all_connections
      end
    end

    describe '.connection_pool' do
      it 'should retrieve connection pool from the connection handler' do
        expect(@mock_connection_handler).to receive(:retrieve_connection_pool).
          with('mysql_group:shard1').
          and_return(double('connection_pool'))
        described_class.connection_pool(:mysql_group, :shard1)
      end

      it 'should raise a ActiveRecord::ConnectionNotEstablished if pool doesnt exist' do
        # pass the call to a real connection handler
        expect(@mock_connection_handler).to receive(:retrieve_connection_pool).once do |connection_name|
          ActiveRecord::ConnectionAdapters::ConnectionHandler.new.retrieve_connection_pool(connection_name)
        end

        expect do
          described_class.connection_pool(:mysql_group, :fake_shard)
        end.to raise_error ActiveRecord::ConnectionNotEstablished
      end
    end

    describe '.retrieve_connection' do
      it 'should retrieve connection from the connection handler' do
        expect(@mock_connection_handler).to receive(:retrieve_connection).once.with('mysql_group:shard1')
        described_class.retrieve_connection(:mysql_group, :shard1)
      end
    end

    describe '.connected?' do
      it 'should check connection through the connection handler' do
        expect(@mock_connection_handler).to receive(:connected?).once.with('mysql_group:shard1')
        described_class.connected?(:mysql_group, :shard1)
      end
    end

    describe '.with_connection' do
      it 'should yield a connection got from the connection handler to a block' do
        mock_connection_pool = double('connection_pool')
        expect(@mock_connection_handler).to receive(:retrieve_connection_pool).
          with('mysql_group:shard1').
          and_return(mock_connection_pool)

        mock_connection = double('connection')
        expect(mock_connection_pool).to receive(:with_connection).once do |&block|
          block.call mock_connection
        end

        described_class.with_connection(:mysql_group, :shard1) do |connection|
          expect(connection).to be == mock_connection
        end
      end
    end

    describe '.remove_connection' do
      it 'should remove connection through the connection handler' do
        expect(@mock_connection_handler).to receive(:remove_connection).once.with('mysql_group:shard1')
        described_class.remove_connection(:mysql_group, :shard1)
      end
    end
  end

end
