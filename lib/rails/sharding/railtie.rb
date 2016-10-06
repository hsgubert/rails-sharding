
module Rails::Sharding

  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/rails-sharding.rake"
    end
  end

end
