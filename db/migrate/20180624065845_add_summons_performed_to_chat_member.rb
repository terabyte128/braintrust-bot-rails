class AddSummonsPerformedToChatMember < ActiveRecord::Migration[5.1]
  def change
    add_column :chat_members, :summons_performed, :integer, default: 0
  end
end
