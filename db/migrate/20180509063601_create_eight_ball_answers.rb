class CreateEightBallAnswers < ActiveRecord::Migration[5.1]
  def change
    create_table :eight_ball_answers do |t|
      t.references :chat, foreign_key: true
      t.text :answer

      t.timestamps
    end
  end
end
