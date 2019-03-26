class AddEnabledToQuotes < ActiveRecord::Migration[5.1]
  def change
    add_column :quotes, :enabled, :boolean, default: true, required: true
  end
end
