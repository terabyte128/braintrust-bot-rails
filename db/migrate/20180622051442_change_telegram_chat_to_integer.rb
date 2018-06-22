class ChangeTelegramChatToInteger < ActiveRecord::Migration[5.1]
  def change
    change_column :chats, :telegram_chat, :integer, limit: 8
  end
end
