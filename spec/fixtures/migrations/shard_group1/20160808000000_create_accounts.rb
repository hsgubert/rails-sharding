class CreateAccounts < ActiveRecord::Migration
  def up
    create_table :accounts do |t|
    end
  end

  def down
    drop_table :accounts
  end
end
