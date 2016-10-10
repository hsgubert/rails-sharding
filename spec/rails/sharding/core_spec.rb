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

      it 'should not establish all connections' do
        expect(Rails::Sharding::ActiveRecordExtensions).not_to receive(:extend_active_record_scope)
        Rails::Sharding::Core.setup do |config|
          config.extend_active_record_scope = false
        end
      end
    end
  end

  describe '.configurations' do
    it 'should load shards.yml scoped by the current Rails.env or explicitly passed environment' do
      expect(described_class.configurations).to be == YAML.load_file('spec/fixtures/shards.yml')['development']
      expect(described_class.configurations('test')).to be == YAML.load_file('spec/fixtures/shards.yml')['test']
    end

    it 'should raise error is shards.yml file is not found' do
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
  end

  describe '.test_configurations' do
    it 'should load shards.yml scoped by the test environment' do
      expect(described_class.test_configurations).to be == YAML.load_file('spec/fixtures/shards.yml')['test']
    end
  end

  describe '.shard_groups' do
    it 'should return an array of all existing shard groups in shards.yml' do
      expect(described_class.shard_groups).to be == ['shard_group1']
    end
  end

  describe '.shard_names' do
    it 'should return an array of all existing shard groups in shards.yml' do
      expect(described_class.shard_names('shard_group1')).to be == ['shard1', 'shard2']
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
      described_class.using_shard(:shard_group1, :shard1) do
        expect(Rails::Sharding::ShardThreadRegistry.connecting_to_shard?).to be true

        # avoids warning of unused connection during tests
        expect(Rails::Sharding::ShardThreadRegistry.shard_connection_used).to be false
        Rails::Sharding::ShardThreadRegistry.shard_connection_used = true
      end
      expect(Rails::Sharding::ShardThreadRegistry.connecting_to_shard?).to be false
    end

    it 'should release shard connection from connection pool upon finishing the block' do
      described_class.using_shard(:shard_group1, :shard1) do
        expect(Rails::Sharding::ConnectionHandler.connection_pool(:shard_group1, :shard1)).to receive(:release_connection).once

        # avoids warning of unused connection during tests
        expect(Rails::Sharding::ShardThreadRegistry.shard_connection_used).to be false
        Rails::Sharding::ShardThreadRegistry.shard_connection_used = true
      end
    end
  end
end
