module Support
  module TestHelpers

    def clear_data_from_all_shards
      Rails::Sharding.shard_groups.each do |shard_group|
        Rails::Sharding.shard_names(shard_group).each do |shard_name|
          Rails::Sharding.using_shard(shard_group, shard_name) do
            Account.delete_all
            User.delete_all
          end
        end
      end
    end

  end
end
