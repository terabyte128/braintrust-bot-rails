class CreateLuckHistories < ActiveRecord::Migration[5.1]
  def change
    create_table :luck_histories do |t|
      t.references :member, foreign_key: true
      t.integer :luck

      t.timestamps
    end
  end
end
