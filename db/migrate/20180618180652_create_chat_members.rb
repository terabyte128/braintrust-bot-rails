class CreateChatMembers < ActiveRecord::Migration[5.1]
  def change
    create_table :chat_members do |t|
      t.references :chat, foreign_key: true
      t.references :member, foreign_key: true

      t.timestamps
    end
  end
end
