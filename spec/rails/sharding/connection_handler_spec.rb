require 'spec_helper'
require './spec/fixtures/models/account'
require './spec/fixtures/models/user'

describe Rails::Sharding::ConnectionHandler do

  context 'using real database' do
    before { clear_data_from_all_shards }
    after { clear_data_from_all_shards }

    it 'should add shard tag to ActiveRecord query logs' do
      original_logger = Account.logger
      begin
        Account.logger = User.logger = spy('logger')

        Rails::Sharding.using_shard(:mysql_group, :shard1) { Account.first }
        expect(Account.logger).to have_received(:debug).once.with(/Account Load \(mysql_group:shard1\)/ )

        Rails::Sharding.using_shard(:mysql_group, :shard2) { Account.count }
        expect(Account.logger).to have_received(:debug).once.with(/\(mysql_group:shard2\)/ )

        Rails::Sharding.using_shard(:postgres_group, :shard1) { User.first }
        expect(User.logger).to have_received(:debug).once.with(/User Load \(postgres_group:shard1\)/ )

        Rails::Sharding.using_shard(:postgres_group, :shard2) { User.count }
        expect(User.logger).to have_received(:debug).once.with(/\(postgres_group:shard2\)/ )
      ensure
        Account.logger = User.logger = original_logger
      end
    end

    it 'should add shard tag to retrieved connection query logs' do
      original_logger = ActiveRecord::Base.logger
      begin
        ActiveRecord::Base.logger = spy('logger')

        connection = described_class.retrieve_connection(:mysql_group, :shard2)
        connection.execute('SELECT 1 FROM accounts', 'Custom Query')
        expect(ActiveRecord::Base.logger).to have_received(:debug).once.with(/Custom Query \(mysql_group:shard2\)/ )

        connection = described_class.retrieve_connection(:postgres_group, :shard2)
        connection.execute('SELECT 1 FROM accounts', 'Custom Query')
        expect(ActiveRecord::Base.logger).to have_received(:debug).once.with(/Custom Query \(postgres_group:shard2\)/ )
      ensure
        ActiveRecord::Base.logger = original_logger
      end
    end

    it 'should add shard tag to yielded connection query logs' do
      original_logger = ActiveRecord::Base.logger
      begin
        ActiveRecord::Base.logger = spy('logger')

        described_class.with_connection(:mysql_group, :shard2) do |connection|
          connection.execute('SELECT 1 FROM accounts', 'Custom Query')
        end
        expect(ActiveRecord::Base.logger).to have_received(:debug).once.with(/Custom Query \(mysql_group:shard2\)/ )

        described_class.with_connection(:postgres_group, :shard2) do |connection|
          connection.execute('SELECT 1 FROM accounts', 'Custom Query')
        end
        expect(ActiveRecord::Base.logger).to have_received(:debug).once.with(/Custom Query \(postgres_group:shard2\)/ )
      ensure
        ActiveRecord::Base.logger = original_logger
      end
    end

    it 'should not tag query logs if this option is disabled on setup' do
      original_logger = ActiveRecord::Base.logger
      begin
        Rails::Sharding.setup do |config|
          config.add_shard_tag_to_query_logs = false
        end
        ActiveRecord::Base.logger = spy('logger')

        connection = described_class.retrieve_connection(:mysql_group, :shard2)
        connection.execute('SELECT 1 FROM accounts', 'Custom Query')
        expect(ActiveRecord::Base.logger).not_to have_received(:debug).with(/Custom Query \(mysql_group:shard2\)/ )
        expect(ActiveRecord::Base.logger).to have_received(:debug).once.with(/Custom Query/ )
      ensure
        ActiveRecord::Base.logger = original_logger
      end
    end
  end


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
        expect(@mock_connection_handler).to receive(:establish_connection).once do |connection_spec|
          expect(connection_spec.name).to be == 'postgres_group:shard1'
        end
        expect(@mock_connection_handler).to receive(:establish_connection).once do |connection_spec|
          expect(connection_spec.name).to be == 'postgres_group:shard2'
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
        allow(mock_connection).to receive :execute
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
