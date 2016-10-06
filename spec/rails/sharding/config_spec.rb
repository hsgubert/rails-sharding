require 'spec_helper'

describe Rails::Sharding::Config do
  it 'should have accessors for all configurations, initialized with default values' do
    Rails::Sharding::Config::DEFAULT_CONFIGS.each do |config_name, default_value|
      # test reader
      expect(described_class.send(config_name)).to be == default_value

      # test writter
      expect(described_class.send(config_name.to_s + '=', 1435))
      expect(described_class.send(config_name)).to be == 1435

      # restores default value
      expect(described_class.send(config_name.to_s + '=', default_value))
    end
  end
end
