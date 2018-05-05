class RenameTelegramId < ActiveRecord::Migration[5.1]
  def change
    rename_column :chats, :telegram_id, :telegram_chat
  end
end
