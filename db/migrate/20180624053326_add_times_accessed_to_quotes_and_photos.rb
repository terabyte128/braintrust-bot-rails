class AddTimesAccessedToQuotesAndPhotos < ActiveRecord::Migration[5.1]
  def change
    add_column :photos, :times_accessed, :integer, default: 0
    add_column :quotes, :times_accessed, :integer, default: 0
  end
end
