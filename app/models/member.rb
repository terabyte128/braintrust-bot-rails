class Member < ApplicationRecord
  has_many :chat_members
  has_many :chats, through: :chat_members
  has_many :quotes
  has_many :photos

  validates_uniqueness_of :username, allow_blank: true, allow_nil: true, case_sensitive: false
  validates_uniqueness_of :telegram_user, allow_blank: true, allow_nil: true

  # either username or a telegram ID is required
  validates_presence_of :username, unless: Proc.new { |m| m.telegram_user.present? }
  validates_presence_of :telegram_user, unless: Proc.new { |m| m.username.present? }

  def display_name
    pretty_name(self)
  end
end
