class Quote < ApplicationRecord
  belongs_to :chat
  validates_presence_of :author, :content
end
