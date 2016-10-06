require 'spec_helper'

describe Rails::Sharding do
  it 'has a version number' do
    expect(Rails::Sharding::VERSION).not_to be nil
  end

  it 'loads sharding core' do
    expect(defined? Rails::Sharding::Core).to be_truthy
  end

  it 'loads railtie' do
    expect(defined? Rails::Sharding::Railtie).to be_truthy
    expect(Rails::Sharding::Railtie.superclass).to be == Rails::Railtie
  end

  it 'loads scaffold generator' do
    expect(defined? RailsSharding::ScaffoldGenerator).to be_truthy
    expect(RailsSharding::ScaffoldGenerator.superclass).to be == Rails::Generators::Base
  end

  it 'delegates all methods missing to Rails::Sharding::Core' do
    expect(Rails::Sharding::Core).to receive(:configurations).once
    Rails::Sharding.configurations
  end
end
