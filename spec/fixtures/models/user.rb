class User < ActiveRecord::Base
  include Rails::Sharding::ShardableModel

  belongs_to :account
end
