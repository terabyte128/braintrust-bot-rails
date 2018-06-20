class AddTelegramIdToMembers < ActiveRecord::Migration[5.1]
  def change
    add_column :members, :telegram_user, :integer, limit: 8
  end
end
