class AddBirthdays < ActiveRecord::Migration[5.1]
  def change
    add_column :members, :birthday, :date, null: true, default: nil
    add_column :chats, :birthdays_enabled, :boolean, null: false, default: false
  end
end
