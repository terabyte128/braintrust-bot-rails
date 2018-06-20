class Quote < ApplicationRecord
  belongs_to :chat
  belongs_to :member
  validates_presence_of :author, :content
end
