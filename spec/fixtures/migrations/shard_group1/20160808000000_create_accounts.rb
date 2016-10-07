class CreateAccounts < ActiveRecord::Migration[5.0]
  def up
    create_table :accounts do |t|
    end
  end

  def down
    drop_table :accounts
  end
end
