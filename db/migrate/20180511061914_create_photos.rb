class CreatePhotos < ActiveRecord::Migration[5.1]
  def change
    create_table :photos do |t|
      t.string :sender
      t.text :caption
      t.text :telegram_photo
      t.boolean :confirmed, default: false
      t.references :chat, foreign_key: true

      t.timestamps
    end
  end
end
