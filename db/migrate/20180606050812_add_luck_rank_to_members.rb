class AddLuckRankToMembers < ActiveRecord::Migration[5.1]
  def change
    add_column :members, :luck, :integer, default: 50
  end
end
