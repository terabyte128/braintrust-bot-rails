class CreateAlexas < ActiveRecord::Migration[5.1]
  def change
    create_table :alexas do |t|
      t.references :chat, foreign_key: true
      t.text :device_id

      t.timestamps
    end
  end
end
