

class User < ActiveRecord::Base
  include Rails::Sharding::ShardableModel

  belongs_to :accounts
end
