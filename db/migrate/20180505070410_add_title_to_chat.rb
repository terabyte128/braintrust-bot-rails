class AddTitleToChat < ActiveRecord::Migration[5.1]
  def change
    add_column :chats, :title, :string
  end
end
