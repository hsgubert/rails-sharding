# Rails::Sharding

[![Build Status](https://travis-ci.org/hsgubert/rails-sharding.svg?branch=master)](https://travis-ci.org/hsgubert/rails-sharding)
[![Code Climate](https://codeclimate.com/github/hsgubert/rails-sharding/badges/gpa.svg)](https://codeclimate.com/github/hsgubert/rails-sharding)
[![Test Coverage](https://codeclimate.com/github/hsgubert/rails-sharding/badges/coverage.svg)](https://codeclimate.com/github/hsgubert/rails-sharding/coverage)
[![Gem Version](https://badge.fury.io/rb/rails-sharding.svg)](https://badge.fury.io/rb/rails-sharding)
[![Dependency Status](https://gemnasium.com/badges/github.com/hsgubert/rails-sharding.svg)](https://gemnasium.com/github.com/hsgubert/rails-sharding)

Simple and robust sharding gem for Rails, including Migrations and ActiveRecord extensions

This gems allows you to easily create extra databases to your rails application, and freely allocate ActiveRecord instances to any of the databases. It also provides rake tasks and migrations to help you manage the schema by shard groups.

After you have setup your shards, accessing them is as simple as:
```ruby
  new_user = User.using_shard(:shard_group1, :shard1).create(username: 'x')
  loaded_user = User.using_shard(:shard_group1, :shard1).where(username: 'x').first
```

You can also use the block syntax, where all your queries inside will be directed to the correct shard:
```ruby
  Rails::Sharding.using_shard(:shard_group1, :shard1) do
    new_user = User.create(username: 'x')
    loaded_user = User.where(username: 'x').first
    billing_infos = loaded_user.billing_infos.all
  end
```

You can also pick and choose which models will be shardable, so that all the models that are not shardable will still be retrieved from the master database, even if inside a using_shard block.

## Compatibility
Gem version 1.x.x:
* Rails 5.0 and 5.1
* Databases: MySQL, MariaDB, Postgres

Gem version 0.x.x:
* Rails 4.2
* Databases: MySQL, MariaDB


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails-sharding'
```

And then execute:
```
bundle
```

## Creating Shards
This gem helps you create shards that are additional and completely separate from your master database. The master database is the one that is created and managed through rails, and is the default storage for all your models.

To start with the rails-sharding gem, run the command
```
rails g rails_sharding:scaffold
```

This will generate a `config/shards.yml.example` like this:
```ruby
default: &default
  adapter: mysql2
  encoding: utf8
  reconnect: false
  pool: 5
  username: ___
  password: ___
  socket: /var/run/mysqld/mysqld.sock

development:
  shard_group1:
    shard1:
      <<: *default
      database: group1_shard1_development
    shard2:
      <<: *default
      database: group1_shard2_development
...
```

Rename it to `config/shards.yml` and change it to your database configuration. This example file defines a single shard group (named `shard_group1`) containing two shards (`shard1` and `shard2`). A shard group is simply a set of shards that should have the same schema.

When you're ready to create the shards run
```
rake shards:create
```

## Migrating Shards
Go to the directory `db/shards_migrations/shard_group1` and add all migrations that you want to run on the shards of `shard_group1`. By design, all shards in a same group should always have the same schema. For example, add the following migration to your `db/shards_migrations/shard_group1`:
```ruby
# 20160808000000_create_users.rb
class CreateClients < ActiveRecord::Migration[5.0]
  def up
    create_table :users do |t|
      t.string :username, :limit => 100
      t.timestamps
    end
  end

  def down
    drop_table :users
  end
end
```

Then run:
```
rake shards:migrate
```

All the shards will be migrated, and one schema file will be dumped for each of the shards (just like rails would do for your master database). You can see the schema of the shards in `db/shards_schemas/shard_group1/`, and it will be something like:
```ruby
ActiveRecord::Schema.define(version: 20160808000000) do

  create_table "users", force: :cascade do |t|
    t.string   "username",       limit: 100
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
```

## Other rake tasks
The rails-sharding gem offers several rake tasks analogous to the ones offered by ActiveRecord:
```
rake shards:create                                      
rake shards:drop                                        
rake shards:migrate                                     
rake shards:migrate:down                                
rake shards:migrate:redo                                
rake shards:migrate:reset                               
rake shards:migrate:up                                  
rake shards:rollback                                    
rake shards:schema:dump                                 
rake shards:schema:load                                 
rake shards:test:load_schema                            
rake shards:test:prepare                                
rake shards:test:purge               
rake shards:version
```

They work just the same as the tasks `rake:db:...` but they operate on all shards of all shard groups. If you want to run a rake task just to a specific shard group or shard you can use the `SHARD_GROUP` and `SHARD` options:
```
rake shards:migrate SHARD_GROUP=shard_group_1
rake shards:migrate SHARD_GROUP=shard_group_1 SHARD=shard1
```

## Gem Options
Running the `rails g rails_sharding:scaffold` will create an initializer at `config/initializers/rails-sharding.rb`. You can pass additional configurations on this initializer to control the gem behavior. You can see below all available options and their default values:
```ruby
# config/initializers/rails-sharding.rb

Rails::Sharding.setup do |config|
  # If true one connection will be established per shard (in every shard group) on startup.
  # If false the user must call Shards::ConnectionHandler.establish_connection(shard_group, shard_name) manually at least once before using each shard.
  config.establish_all_connections_on_setup = true

  # If true the method #using_shard will be mixed in ActiveRecord scopes. Put this to false if you don't want the gem to modify ActiveRecord
  config.extend_active_record_scope = true

  # If true the query logs of ActiveRecord will be tagged with the corresponding shard you're querying
  config.add_shard_tag_to_query_logs = true

  # Specifies where to find the definition of the shards configurations
  config.shards_config_file = 'config/shards.yml'

  # Specifies where to find the migrations for each shard group
  config.shards_migrations_dir = 'db/shards_migrations'

  # Specifies where to find the schemas for each shard group
  config.shards_schemas_dir = 'db/shards_schemas'
end
```

## Development and Contributing

After checking out the repo:

1. Run `bundle` to install gems 

1. Create your `spec/fixtures/shards.yml` based on the example on this same folder (you need MySQL and Postgres)

1. Run `rake db:test:prepare` to create the test shards. 

1. Run `rspec` to run the tests.

Bug reports and pull requests are welcome on GitHub at https://github.com/hsgubert/rails-sharding.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Acknowledgements

This gem was inspired on several other gems like: [octopus](https://github.com/thiagopradi/octopus), [shard_handler](https://github.com/locaweb/shard_handler) and [active_record_shards](https://github.com/zendesk/active_record_shards).
