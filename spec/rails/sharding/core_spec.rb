require 'spec_helper'

describe Rails::Sharding::Core do
  describe '.setup' do
    it 'should yield Config class to block' do
      Rails::Sharding::Core.setup do |config|
        expect(config).to be == Rails::Sharding::Config
      end
    end

    describe 'establish_all_connections_on_setup option' do
      it 'should establish all connections' do
        expect(Rails::Sharding::ConnectionHandler).to receive(:establish_all_connections).once
        Rails::Sharding::Core.setup
      end

      it 'should not establish all connections' do
        expect(Rails::Sharding::ConnectionHandler).not_to receive(:establish_all_connections)
        Rails::Sharding::Core.setup do |config|
          config.establish_all_connections_on_setup = false
        end
      end
    end

    describe 'extend_active_record_scope option' do
      it 'should extend activerecord scopes' do
        expect(Rails::Sharding::ActiveRecordExtensions).to receive(:extend_active_record_scope)
        Rails::Sharding::Core.setup
        expect(ActiveRecord::Base).to respond_to :using_shard
      end

      it 'should not extend activerecord scopes' do
        expect(Rails::Sharding::ActiveRecordExtensions).not_to receive(:extend_active_record_scope)
        Rails::Sharding::Core.setup do |config|
          config.extend_active_record_scope = false
        end
      end
    end
  end

  describe '.configurations' do
    let(:shard_configurations) { YAML.load(ERB.new(File.read('spec/fixtures/shards.yml')).result) }

    it 'should load shards.yml scoped by the current Rails.env or explicitly passed environment' do
      expect(described_class.configurations).to be == shard_configurations['development']
      expect(described_class.configurations('test')).to be == shard_configurations['test']
    end

    it 'should load shards.yml different than configuration' do
      stub_const('ENV', 'MYSQL_USERNAME' => 'root1', 'MYSQL_PASSWORD' => '1234')
      expect(described_class.configurations).not_to be == shard_configurations['development']
    end

    it 'should raise error if shards.yml file is not found' do
      described_class.reset_configurations_cache
      original_shards_config_file = Rails::Sharding::Config.shards_config_file
      begin
        Rails::Sharding::Config.shards_config_file = 'wrong/path.yml'
        expect do
          described_class.configurations
        end.to raise_error Rails::Sharding::Errors::ConfigNotFoundError
      ensure
        Rails::Sharding::Config.shards_config_file = original_shards_config_file
      end
    end

    it 'should raise error if shards.yml does not have configuration for environment' do
      expect do
        described_class.configurations('wrong_env')
      end.to raise_error Rails::Sharding::Errors::ConfigNotFoundError
    end
  end

  describe '.test_configurations' do
    it 'should load shards.yml scoped by the test environment' do
      expect(described_class.test_configurations).to be == YAML.load(ERB.new(File.read('spec/fixtures/shards.yml')).result)['test']
    end
  end

  describe '.shard_groups' do
    it 'should return an array of all existing shard groups in shards.yml' do
      expect(described_class.shard_groups).to be == %w[mysql_group postgres_group]
    end
  end

  describe '.shard_names' do
    it 'should return an array of all existing shard groups in shards.yml' do
      expect(described_class.shard_names('mysql_group')).to be == %w[shard1 shard2]
    end
  end

  describe '.for_each_shard' do
    it 'should yield configuration of all shards in all shard groups' do
      yielded_shards = []
      Rails::Sharding.for_each_shard do |shard_group, shard, configuration|
        yielded_shards << [shard_group, shard]
        expect(configuration).to be == Rails::Sharding.configurations[shard_group][shard]
      end

      Rails::Sharding.configurations.each do |shard_group, shards_configs|
        shards_configs.keys.each do |shard|
          expect(yielded_shards).to include [shard_group, shard]
        end
      end
    end
  end

  describe '.using_shard' do
    it 'should yield block with shard set in a thread-specific storage' do
      expect(Rails::Sharding::ShardThreadRegistry.connecting_to_shard?).to be false
      described_class.using_shard(:mysql_group, :shard1) do
        expect(Rails::Sharding::ShardThreadRegistry.connecting_to_shard?).to be true
      end
      expect(Rails::Sharding::ShardThreadRegistry.connecting_to_shard?).to be false
    end

    it 'should release shard connection from connection pool upon finishing the block' do
      described_class.using_shard(:mysql_group, :shard1) do
        expect(Rails::Sharding::ConnectionHandler.connection_pool(:mysql_group,
                                                                  :shard1)).to receive(:release_connection).once
      end
    end

    it 'should print warning if no_connection_retrieved_warning option is set and connection is not used in block' do
      initial_config = Rails::Sharding::Config.no_connection_retrieved_warning
      begin
        Rails::Sharding::Config.no_connection_retrieved_warning = true
        described_class.using_shard(:mysql_group, :shard1) do
          expect(STDOUT).to receive(:puts).with(/Warning: no connection to shard 'mysql_group:shard1' was retrieved inside/)
        end
      ensure
        Rails::Sharding::Config.no_connection_retrieved_warning = initial_config
      end
    end

    it 'should allow nesting' do
      expect(Rails::Sharding::ShardThreadRegistry.current_shard_group_and_name).to be == [nil, nil]

      described_class.using_shard(:mysql_group, :shard1) do
        expect(Rails::Sharding::ShardThreadRegistry.current_shard_group_and_name).to be == %i[mysql_group shard1]
        described_class.using_shard(:mysql_group, :shard2) do
          expect(Rails::Sharding::ShardThreadRegistry.current_shard_group_and_name).to be == %i[mysql_group shard2]
          described_class.using_shard(nil, nil) do
            expect(Rails::Sharding::ShardThreadRegistry.current_shard_group_and_name).to be == [nil, nil]
          end
          expect(Rails::Sharding::ShardThreadRegistry.current_shard_group_and_name).to be == %i[mysql_group shard2]
        end
        expect(Rails::Sharding::ShardThreadRegistry.current_shard_group_and_name).to be == %i[mysql_group shard1]
      end

      expect(Rails::Sharding::ShardThreadRegistry.current_shard_group_and_name).to be == [nil, nil]
    end
  end
end
