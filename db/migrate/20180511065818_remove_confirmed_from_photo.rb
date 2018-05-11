class RemoveConfirmedFromPhoto < ActiveRecord::Migration[5.1]
  def change
    remove_column :photos, :confirmed
  end
end
