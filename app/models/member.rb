class Member < ApplicationRecord
  has_many :chat_members
  has_many :chats, through: :chat_members
  has_many :quotes
  has_many :photos
  has_many :luck_histories
  has_many :messages

  validates_uniqueness_of :username, allow_blank: true, allow_nil: true, case_sensitive: false
  validates_uniqueness_of :telegram_user, allow_blank: true, allow_nil: true

  # either username or a telegram ID is required
  validates_presence_of :username, unless: Proc.new { |m| m.telegram_user.present? }
  validates_presence_of :telegram_user, unless: Proc.new { |m| m.username.present? }

  # try first last, then first, then username
  def display_name(bold=false)
    if self.first_name.present?
      if self.last_name.present?
        formatted = "#{self.first_name} #{self.last_name}"
      else
        formatted = self.first_name
      end
    else
      formatted = self.username
    end

    if bold
      "<b>#{formatted}</b>"
    else
      formatted
    end
  end

  def to_s
    display_name
  end

  def html_link
    "<a href='tg://user?id=#{telegram_user}'>#{display_name}</a>"
  end

  def md_link
    "[#{display_name}](tg://user?id=#{telegram_user})"
  end

  def update_luck_random
    date = DateTime.now


    if !birthday.nil? && birthday.day == date.day && birthday.month == date.month
      new_luck = sample_z_estimate(rand(25..40))
    elsif rand < 0.4
      new_luck = sample_random
    else
      avg_luck = (chats.map{ |c| c.average_luck }).sum / chats.count

      # weight the luck slightly by the average luck of the chat
      diff = (avg_luck - luck) ** (2.0 / 3)
      new_luck = sample_z_estimate(diff)
    end

    update_luck new_luck
  end

  # set new luck and add it to the historical database
  def update_luck(new_luck)
    self.update_attribute :luck, new_luck
    self.luck_histories.create luck: new_luck
  end

  private
  # quick 'n dirty way to sample from a normal-ish distribution with "reasonable" accuracy
  def sample_z_estimate(luck_increase=0)
    samples = []

    12.times do |_|
      samples << rand(self.luck - 50 + luck_increase..self.luck + 50 + luck_increase)
    end

    samples.reduce(:+) / samples.size
  end

  # random number from 1 to 100
  def sample_random
    rand(0..100)
  end
end
