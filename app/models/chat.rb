class Chat < ApplicationRecord
  validates_presence_of :telegram_chat
  has_many :quotes
end
