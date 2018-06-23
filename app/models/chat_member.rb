class ChatMember < ApplicationRecord
  belongs_to :chat
  belongs_to :member

  validates :chat_id, uniqueness: { scope: :member_id }
end
