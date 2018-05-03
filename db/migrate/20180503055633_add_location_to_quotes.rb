class AddLocationToQuotes < ActiveRecord::Migration[5.1]
  def change
    add_column :quotes, :longitude, :decimal, precision: 12, scale: 7
    add_column :quotes, :latitude, :decimal, precision: 12, scale: 7
  end
end
