require 'spec_helper'
require './spec/fixtures/models/account'
require './spec/fixtures/models/user'

describe Rails::Sharding::ActiveRecordExtensions do

  before do
    clear_data_from_all_shards
  end

  after do
    clear_data_from_all_shards
  end

  describe '#using_shard method in model classes' do
    it 'should select shard' do
      # creates account on shard1
      expect(Account.using_shard(:shard_group1, :shard1).first).to be_nil
      new_account = Account.using_shard(:shard_group1, :shard1).create
      expect(Account.using_shard(:shard_group1, :shard1).first).to be == new_account

      # checks shard2 has no account
      expect(Account.using_shard(:shard_group1, :shard2).first).to be_nil
    end

    it 'should allow chaining after it is called' do
      new_account = Account.using_shard(:shard_group1, :shard1).create

      expect(Account.using_shard(:shard_group1, :shard1).where(id: new_account.id).first).to be == new_account
      expect(Account.using_shard(:shard_group1, :shard1).where(id: new_account.id + 1).first).to be_nil
    end
  end

  describe '#using_shard method in relations' do
    it 'should allow chaining before it is called' do
      new_user = User.using_shard(:shard_group1, :shard1).create(:username => 'test_username')

      expect(User.where('username="test_username"').using_shard(:shard_group1, :shard1).first).to be == new_user
      expect(User.where('username="other_username"').using_shard(:shard_group1, :shard1).first).to be_nil
    end

    it 'should allow chaining before and after it is called' do
      new_user = User.using_shard(:shard_group1, :shard1).create(:username => 'test_username')

      expect(User.where('username="test_username"').using_shard(:shard_group1, :shard1).where(id: new_user.id).first).to be == new_user
      expect(User.where('username="test_username"').using_shard(:shard_group1, :shard1).where(id: new_user.id + 1).first).to be_nil
    end

    it 'should allow chaining before called with explicit attributes of the model' do
      skip('doenst work for now')
      new_user = User.using_shard(:shard_group1, :shard1).create(:username => 'test_username')

      # This test doesn't pass because when we pass a hash to where, it checks the database for the model
      # attributes. Since this happens before we call using_shard, it crashes.
      # Solution would be to perhaps say in the model that the master_database
      # doesn't include a table for the model, and set a default shard for AR
      # to look for column names
      expect(User.where(username: "test_username").using_shard(:shard_group1, :shard1).first).to be == new_user
    end
  end

  describe '#using_shard method in associations' do
    it 'should work for a has_many association' do
      skip('doenst work for now')

      # This test doesn't pass because when we access a relation AR tries to access
      # the DB connection (before we switch the connection)

      new_account = Account.using_shard(:shard_group1, :shard1).create!
      new_user = User.using_shard(:shard_group1, :shard1).create!(:username => 'test_username', :account_id => new_account.id)

      new_account = Account.using_shard(:shard_group1, :shard1).first
      expect(new_account.users.using_shard(:shard_group1, :shard1).first).to be == new_user
      expect(new_account.users.using_shard(:shard_group1, :shard2).first).to be_nil
    end
  end

  describe '#using_shard method in model instance' do
    it 'should work before reloading' do
      new_user = User.using_shard(:shard_group1, :shard1).create(:username => 'test_username')

      Rails::Sharding.using_shard(:shard_group1, :shard1) do
        loaded_user = User.first
        loaded_user.update_column(:username, 'another_username')
      end

      expect(new_user.username).to be == 'test_username'
      new_user.using_shard(:shard_group1, :shard1).reload
      expect(new_user.username).to be == 'another_username'
    end
  end

private

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
