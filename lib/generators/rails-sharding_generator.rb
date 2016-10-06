require 'rails/generators/base'

class InitializerGenerator < Rails::Generators::Base

  def copy_initializer
    copy_file 'templates/rails-sharding_initializer.rb', 'config/initializers/rails-sharding.rb'
  end

  def copy_configuration_example
    copy_file 'templates/shards.yml.example', 'config/shards.yml.example'
  end
end
