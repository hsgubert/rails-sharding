require 'rails/generators'

module RailsSharding
  class ScaffoldGenerator < Rails::Generators::Base
    source_root File.expand_path('../templates', __FILE__)

    def copy_initializer
      copy_file 'rails-sharding_initializer.rb', 'config/initializers/rails-sharding.rb'
    end

    def copy_configuration_file_and_example
      copy_file 'shards.yml.example', Rails::Sharding::Config.shards_config_file + '.example'
      copy_file 'shards.yml.example', Rails::Sharding::Config.shards_config_file
    end

    def add_configuration_to_gitignore
      append_to_file '.gitignore' do
        "\n" + Rails::Sharding::Config.shards_config_file
      end
    end

    def create_migrations_and_schema_directory
      empty_directory Rails::Sharding::Config.shards_migrations_dir
      empty_directory Rails::Sharding::Config.shards_schemas_dir
    end
  end
end
