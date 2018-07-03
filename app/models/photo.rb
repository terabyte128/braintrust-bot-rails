class Photo < ApplicationRecord
  belongs_to :chat
  belongs_to :member, optional: true

  def display_name
    "#{member ? member.display_name : '???'} in #{chat.display_name}"
  end
end
