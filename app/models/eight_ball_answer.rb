class EightBallAnswer < ApplicationRecord
  belongs_to :chat

  def display_name
    answer
  end
end
