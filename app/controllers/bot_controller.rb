class BotController < Telegram::Bot::UpdatesController

  before_action :find_or_create_chat

  def message(message)
    # get the latest quote sent by this sender in this chat
    latest_quote = @chat.quotes.order(created_at: :desc).where(sender: from['username']).first

    if update['message'].key? 'location'
      unless latest_quote.location_confirmed
        location = update['message']['location']

        latest_quote.longitude = location['longitude']
        latest_quote.latitude = location['latitude']
        respond_with :message, text: '🗺 A location was added to your latest quote!'
      end
    end

    latest_quote.location_confirmed = true
    latest_quote.save
  end

  # The format of a quote is
  # content && author && context
  # where context is optional.
  def sendquote(*args)
    # tokenize the quote into content, author, and (optional) context
    tokens = args.join(' ').split('&&')

    # we need either 2 or 3 tokens for a valid quote
    unless tokens.length.between?(2, 3)
      respond_with :message, text: "🧐 Usage: /sendquote [quote] && [author] && [optional context]"
      return
    end

    tokens.map! { |t| t.strip } # remove leading and trailing whitespace
    new_quote = @chat.quotes.new content: tokens[0], author: tokens[1], sender: from['username']

    if tokens.length == 3
      new_quote.context = tokens[2]
    end

    if new_quote.save
      respond_with :message, text: '👌 Your quote was saved!'
    else
      respond_with :message, text: "🤬 Failed to save quote: #{new_quote.errors.full_messages} (@SamWolfson should fix this)"
    end
  end

  # shortcut method for sendquote
  def sq(*args)
    sendquote(args)
  end

  def getquote(*args)
    # the sender can optionally pass the author as an argument if they only want specific authors
    author = args.join(' ')

    if author.empty?
      quotes = @chat.quotes
    else
      quotes = @chat.quotes.where 'LOWER(author) LIKE ?', "%#{author.downcase}%"
    end

    if quotes.empty?
      respond_with :message, text: "😭 You don't have any quotes#{" by <b>#{author}</b>" unless author.empty?}! Use /sendquote to add some.", parse_mode: :html
    else
      quote = quotes.sample
      respond_with :message, text: format_quote(quote.content, quote.author, quote.context, quote.created_at.year), parse_mode: :html
    end
  end

  # shortcut method for getquote
  def gq(*args)
    getquote(args)
  end

  private

  def find_or_create_chat
    @chat = Chat.where(telegram_chat: chat['id']).first_or_create do |chat|
      chat.title = chat['title']
    end
  end

  # Build an HTML-formatted quote to display to the user
  def format_quote(content, author, context, date)
    quote = "\"<i>#{content}</i>\"\n<b> - #{author} #{date}</b>"
    if context
      quote << " (#{context})"
    end
    quote
  end
end