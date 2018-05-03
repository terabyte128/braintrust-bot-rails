class Chat < ApplicationRecord
  validates_presence_of :telegram_id
end
