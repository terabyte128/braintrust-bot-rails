class CreateChats < ActiveRecord::Migration[5.1]
  def change
    create_table :chats do |t|
      t.string :telegram_id, null: false, unique: true
      t.boolean :quotes_enabled, null: false, default: false

      t.timestamps
    end
  end
end
