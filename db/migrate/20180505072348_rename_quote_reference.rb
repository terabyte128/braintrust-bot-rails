class RenameQuoteReference < ActiveRecord::Migration[5.1]
  def change
    rename_column :quotes, :chat_id_id, :chat_id
  end
end
