require 'spec_helper'

describe Rails::Sharding::Config do
  it 'should have accessors for all configurations, initialized with default values' do
    Rails::Sharding::Config::DEFAULT_CONFIGS.each do |config_name, default_value|
      # test reader and initial value
      unless config_name.to_sym.in? $rails_sharding_configs_changed
        expect(described_class.send(config_name)).to be == default_value
      end

      # test writter
      initial_value = described_class.send(config_name)
      expect(described_class.send(config_name.to_s + '=', 1435))
      expect(described_class.send(config_name)).to be == 1435

      # restores initial value
      expect(described_class.send(config_name.to_s + '=', initial_value))
    end
  end
end
