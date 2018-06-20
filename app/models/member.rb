class Member < ApplicationRecord
  has_many :chat_members
  has_many :chats, through: :chat_members
  has_many :quotes
  has_many :photos
end
