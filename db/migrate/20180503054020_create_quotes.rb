class CreateQuotes < ActiveRecord::Migration[5.1]
  def change
    create_table :quotes do |t|
      t.references :chat_id, foreign_key: true
      t.text :content, null: false
      t.text :context
      t.string :author, null: false
      t.string :sender

      t.timestamps
    end
  end
end
