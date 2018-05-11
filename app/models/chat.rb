class Chat < ApplicationRecord
  validates_presence_of :telegram_chat
  has_many :quotes
  has_many :members
  has_many :eight_ball_answers
  has_many :photos
end
