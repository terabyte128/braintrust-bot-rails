class AddStickersToEightBallAnswers < ActiveRecord::Migration[5.1]
  def change
    add_column :eight_ball_answers, :telegram_sticker, :text, null: true
    change_column :eight_ball_answers, :answer, :text, null: false
  end
end
