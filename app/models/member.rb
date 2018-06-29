class Member < ApplicationRecord
  has_many :chat_members
  has_many :chats, through: :chat_members
  has_many :quotes
  has_many :photos
  has_many :luck_histories

  validates_uniqueness_of :username, allow_blank: true, allow_nil: true, case_sensitive: false
  validates_uniqueness_of :telegram_user, allow_blank: true, allow_nil: true

  # either username or a telegram ID is required
  validates_presence_of :username, unless: Proc.new { |m| m.telegram_user.present? }
  validates_presence_of :telegram_user, unless: Proc.new { |m| m.username.present? }

  def display_name
    pretty_name(self)
  end

  def to_s
    display_name
  end

  def update_luck_random
    if rand < 0.4
      new_luck = sample_random
    else
      new_luck = sample_z_estimate
    end

    update_luck new_luck
  end

  def update_luck(new_luck)
    self.luck_histories.create luck: self.luck
    self.update_attribute :luck, new_luck
  end

  private
  # quick 'n dirty way to sample from a normal-ish distribution with "reasonable" accuracy
  def sample_z_estimate
    samples = []

    6.times do |_|
      samples << rand(self.luck - 50..self.luck + 50)
    end

    val = samples.reduce(:+) / samples.size
    [[100, val].min, 0].max
  end

  # random number from 1 to 100
  def sample_random
    rand(0..100)
  end
end
