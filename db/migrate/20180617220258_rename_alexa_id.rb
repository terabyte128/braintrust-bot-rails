class RenameAlexaId < ActiveRecord::Migration[5.1]
  def change
    rename_column :alexas, :device_id, :device_user
  end
end
