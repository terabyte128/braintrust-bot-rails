class CreateMembers < ActiveRecord::Migration[5.1]
  def change
    create_table :members do |t|
      t.references :chat, foreign_key: true
      t.text :username

      t.timestamps
    end
  end
end
