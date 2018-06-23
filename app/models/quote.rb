class Quote < ApplicationRecord
  belongs_to :chat
  belongs_to :member, optional: true
  validates_presence_of :author, :content

  def display_name
    "#{member ? pretty_name(member) : '???'} in #{chat.display_name}"
  end
end
