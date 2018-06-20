class QuotesAndPhotosBelongToChatsAndMembers < ActiveRecord::Migration[5.1]
  def change
    remove_column :quotes, :sender, :integer
    remove_column :photos, :sender, :integer

    add_reference :quotes, :member, index: true
    add_reference :photos, :member, index: true
  end
end
