class AddLocationConfirmedToQuotes < ActiveRecord::Migration[5.1]
  def change
    add_column :quotes, :location_confirmed, :boolean, default: false
  end
end
