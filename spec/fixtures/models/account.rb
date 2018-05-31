class Account < ActiveRecord::Base
  include Rails::Sharding::ShardableModel

  has_many :users
end
