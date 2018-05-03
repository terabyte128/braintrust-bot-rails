class Quote < ApplicationRecord
  belongs_to :chat_id
  validates_presence_of :author, :content
end
