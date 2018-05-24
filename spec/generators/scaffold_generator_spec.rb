require 'spec_helper'

describe RailsSharding::ScaffoldGenerator do
  it 'should have source_root set to templates dir' do
    expect(RailsSharding::ScaffoldGenerator.source_root).to include "rails-sharding/lib/generators/templates"
  end

  describe 'generator methods' do
    before do
      @generator = RailsSharding::ScaffoldGenerator.new
      allow(@generator).to receive :copy_file
    end

    describe '#copy_initializer' do
      it 'should copy initializer from templates to rails app' do
        expect(@generator).to receive(:copy_file).with('rails-sharding_initializer.rb', anything).once
        @generator.copy_initializer
      end
    end

    describe '#copy_configuration_file_and_example' do
      it 'should copy config file from templates to rails app' do
        expect(@generator).to receive(:copy_file).with('shards.yml.example', anything).twice
        @generator.copy_configuration_file_and_example
      end
    end

    describe '#add_configuration_to_gitignore' do
      it 'should append line to gitignore' do
        expect(@generator).to receive(:append_to_file).with('.gitignore').once do |_, &block|
          expect(block.call).to be == "\n" + Rails::Sharding::Config.shards_config_file
        end
        @generator.add_configuration_to_gitignore
      end
    end

    describe '#create_migrations_and_schema_directory' do
      it 'should create two empty directories' do
        expect(@generator).to receive(:empty_directory).twice
        @generator.create_migrations_and_schema_directory
      end
    end

  end
end
