class Alexa < ApplicationRecord
  belongs_to :chat, optional: true
  validates_presence_of :device_user
  validates_uniqueness_of :device_user
end
