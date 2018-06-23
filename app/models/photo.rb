class Photo < ApplicationRecord
  belongs_to :chat
  belongs_to :member, optional: true

  def display_name
    "#{member ? pretty_name(member) : '???'} in #{chat.display_name}"
  end
end
