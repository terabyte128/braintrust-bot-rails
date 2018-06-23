class AddUniqueConstraintToChatMember < ActiveRecord::Migration[5.1]
  def change
    add_index :chat_members, [:chat_id, :member_id], unique: true
  end
end
