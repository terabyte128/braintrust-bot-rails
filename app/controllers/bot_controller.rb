require "#{Rails.root}/lib/helpers/application_helpers"
include ApplicationHelpers

class BotController < Telegram::Bot::UpdatesController

  before_action :find_or_create_chat

  def message(update)
    # handle messages that begin with the bot's username specially
    if update.key?('text') && update['text'].downcase.starts_with?("@" + Telegram.bot.username.downcase)
      # pluck out the text from the update, cut out the @botusername part,
      # split it into an array (as summon would expect), and splat it for args to summon
      summon *update['text'][Telegram.bot.username.length + 1..-1].split(' ')
      return
    end

    # get the latest quote sent by this sender in this chat
    latest_quote = @chat.quotes.order(created_at: :desc).where(sender: from['username']).first

    # if there's a location in the update and the sender's latest quote does not have a confirmed location
    # then add the longitude and latitude to their location (for Gwen)
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
    sendquote(*args)
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
    getquote(*args)
  end

  # shortcut method for getquote and sendquote
  # if no arguments are passed, calls getquote; else calls sendquote
  def quote(*args)
    if args.empty?
      getquote *args
    else
      sendquote *args
    end
  end

  # add users to the chat group
  def add(*user_names)
    user_names = process_users user_names

    # add all the rest to the group
    user_names.each do |u|
      @chat.members.where(username: u).first_or_create
    end

    user_names.map! { |u| "<b>#{u}</b>" }

    if user_names.empty?
      respond_with :message, text: '🧐 Usage: /add [usernames...]'
    else
      respond_with :message, text: "👏 #{user_names.to_sentence} #{user_names.size == 1 ? 'was' : 'were'} added to the chat group!", parse_mode: :html
    end
  end

  # remove users from the chat group
  def remove(*user_names)
    user_names = process_users user_names

    # add all the rest to the group
    user_names.each do |u|
      @chat.members.where(username: u).delete_all
    end

    user_names.map! { |u| "<b>#{u}</b>" }

    if user_names.empty?
      respond_with :message, text: '🧐 Usage: /remove [usernames...]'
    else
      respond_with :message, text: "😢 #{user_names.to_sentence} #{user_names.size == 1 ? 'was' : 'were'} removed from the chat group!", parse_mode: :html
    end
  end

  # get all members in the chat group
  def members
    chat_members = @chat.members.map { |m| "<b>#{m.username}</b>" }
    respond_with :message, text: "📜 Chat group members: #{chat_members.sort.to_sentence}", parse_mode: :html
  end

  # send a summon to all messages in the chat group, with an optional message
  def summon(*message)
    chat_members = @chat.members.map { |m| "@#{m.username}" }
    chat_members.select! { |m| m !=  from['username'].downcase }

    announcement = "📣 <b>#{ if from.key? 'first_name' then from['first_name'] else from['username'] end }</b>\n"

    if message.empty?
      announcement << "\n"
    else
      announcement << message.join(' ') << "\n\n"
    end

    announcement << chat_members.join(', ')

    respond_with :message, text: announcement, parse_mode: :html
  end

  # shorthand for summon
  def s(*message)
    summon *message
  end

  def quotes(*preferences)
    if preferences.length != 1
      respond_with :message, text: "🧐 Usage: /quotes [enable | disable]"
      return
    end

    preference = preferences[0]

    if preference == 'enable'
      @chat.quotes_enabled = true
      respond_with :message, text: "🙌 Quotes enabled!"
    elsif preference == 'disable'
      @chat.quotes_enabled = false
      respond_with :message, text: "🤐 Quotes disabled!"
    else
      respond_with :message, text: "🧐 Usage: /quotes [enable | disable]"
      return
    end

    @chat.save
  end

  def on_8ball
    answer = @chat.eight_ball_answers.sample

    if answer.nil?
      respond_with :message, text: "🤐 <i>You've got no answers, guess you're SOL.</i>", parse_mode: :html
    else
      respond_with :message, text: "<i>#{answer.answer}</i>", parse_mode: :html
    end
  end

  private

  def find_or_create_chat
    @chat = Chat.where(telegram_chat: chat['id']).first_or_create do |chat|
      chat.title = chat['title']
    end
  end

  # Given a list of usernames, remove leading @s, remove duplicates, sort and downcase them
  def process_users(user_names)
    # remove leading @ and downcase
    user_names = user_names.map { |u| if u.start_with? '@' then u[1..-1].downcase else u.downcase end }

    # filter out blank users
    user_names = user_names.select { |u| !u.blank? }

    # remove duplicates
    user_names.uniq.sort
  end
end