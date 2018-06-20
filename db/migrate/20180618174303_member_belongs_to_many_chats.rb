class MemberBelongsToManyChats < ActiveRecord::Migration[5.1]
  def change
    remove_column :members, :chat_id
  end
end
