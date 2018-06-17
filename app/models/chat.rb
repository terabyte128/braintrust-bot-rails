class Chat < ApplicationRecord
  validates_presence_of :telegram_chat
  has_many :quotes
  has_many :members
  has_many :eight_ball_answers
  has_many :photos
  has_many :alexas

  # generate a random quote from this chat
  # will use markov ONLY IF author is nil
  # and use_markov is set. Returns nil if no quotes were found
  def random_quote(use_markov, author)
    if self.quotes.empty?
      return nil
    end

    if use_markov && !author
      # generate a markov quote
      markov = MarkyMarkov::TemporaryDictionary.new

      self.quotes.each do |quote|
        markov.parse_string quote.content
      end

      author = self.quotes.sample.author

      Quote.new(
          content: markov.generate_n_words(rand(8..16)),
          author: author,
          created_at: Date.new(2000 + rand(16..18), 1, 1))
    else
      if author
        quotes = self.quotes.where 'LOWER(author) LIKE ?', "%#{author.downcase}%"
      else
        quotes = self.quotes
      end

      quotes.sample
    end
  end
end
