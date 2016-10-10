require 'spec_helper'

describe Rails::Sharding::ShardThreadRegistry do

  before do
    Rails::Sharding::ShardThreadRegistry.connect_back_to_master!
  end

  after do
    Rails::Sharding::ShardThreadRegistry.connect_back_to_master!
  end

  describe '.current_shard_group and .current_shard_name' do
    it 'should be a symbol-typed variable that does not allow empty string' do
      expect(described_class.current_shard_group).to be_nil
      expect(described_class.current_shard_name).to be_nil

      described_class.current_shard_group = 'shard_group1'
      described_class.current_shard_name = 'shard1'
      expect(described_class.current_shard_group).to be == :shard_group1
      expect(described_class.current_shard_name).to be == :shard1

      described_class.current_shard_group = ''
      described_class.current_shard_name = ''
      expect(described_class.current_shard_group).to be_nil
      expect(described_class.current_shard_name).to be_nil
    end

    it 'should be a thread-specific variable' do
      main_thread = Thread.current
      described_class.current_shard_group = :shard_group1
      described_class.current_shard_name = :shard1

      secondary_thread = Thread.new do
        described_class.current_shard_group = :shard_group2
        described_class.current_shard_name = :shard2
        main_thread.wakeup
        Thread.stop
        expect(described_class.current_shard_group).to be == :shard_group2
        expect(described_class.current_shard_name).to be == :shard2
      end

      Thread.stop
      expect(described_class.current_shard_group).to be == :shard_group1
      expect(described_class.current_shard_name).to be == :shard1

      secondary_thread.wakeup
      secondary_thread.join
    end
  end

  describe '.connecting_to_master? and .connecting_to_shard?' do
    it 'should indicate whether shard_group and shard_name are both set or not' do
      expect(described_class.connecting_to_master?).to be true
      expect(described_class.connecting_to_shard?).to be false

      described_class.current_shard_group = :shard_group1
      expect(described_class.connecting_to_master?).to be true
      expect(described_class.connecting_to_shard?).to be false

      described_class.current_shard_name = :shard1
      expect(described_class.connecting_to_master?).to be false
      expect(described_class.connecting_to_shard?).to be true
    end
  end

  describe '.connect_back_to_master!' do
    it 'should reset all thread-specific variables' do
      described_class.current_shard_group = :shard_group1
      described_class.current_shard_name = :shard1
      described_class.shard_connection_used = true

      described_class.connect_back_to_master!

      expect(described_class.current_shard_group).to be_nil
      expect(described_class.current_shard_name).to be_nil
      expect(described_class.current_shard_name).to be_falsey
    end
  end

end
