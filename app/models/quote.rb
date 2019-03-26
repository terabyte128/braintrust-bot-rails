class Quote < ApplicationRecord
  belongs_to :chat
  belongs_to :member, optional: true
  validates_presence_of :author, :content
  validates :enabled, null: false

  def display_name
    "#{member ? member.display_name : '???'} in #{chat.display_name}"
  end

  def format
    quote = "\"<i>#{self.content.upcase_first}</i>\"\n<b> - #{self.author.titleize} #{self.created_at.year}</b>"
    if self.context.present?
      quote << " (#{self.context})"
    end
    quote
  end
end
