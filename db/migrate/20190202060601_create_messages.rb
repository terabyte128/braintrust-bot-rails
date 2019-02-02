class CreateMessages < ActiveRecord::Migration[5.1]
  def change
    create_table :messages do |t|
      t.references :chat, foreign_key: true
      t.references :member, foreign_key: true
      t.text :content
      t.integer :telegram_message

      t.timestamps
    end
  end
end
