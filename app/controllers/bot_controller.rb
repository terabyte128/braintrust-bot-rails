require "#{Rails.root}/lib/helpers/application_helpers"
require 'open-uri'
require 'fileutils'
include ApplicationHelpers

class BotController < Telegram::Bot::UpdatesController

  before_action :find_or_create_chat

  BotController.session_store = :file_store, Rails.root.join('tmp', 'session_store')

  use_session!

  def message(update)
    # assume that the next message they send means they don't want to add location (unless that message is a location)
    latest_quote = @chat.quotes.order(created_at: :desc).where(sender: from['username'], location_confirmed: false).first

    unless latest_quote.nil?
      latest_quote.location_confirmed = true
      latest_quote.save
    end

    if update.key?('photo')
      photo_sizes = update['photo']

      # pick the largest photo of all sent
      largest_photo = photo_sizes.reduce do |acc, photo|
        acc['file_size'] > photo['file_size'] ? acc : photo
      end

      # cache the photo ID in case they want to save it
      session[:photo] = largest_photo['file_id']
    end

    # handle messages that begin with special prefixes
    if update.key?('text')
      prefixes = ["@#{Telegram.bot.username.downcase}", '@channel', '@everyone', '@all', '@people']

      prefixes.each do |prefix|
        if update['text'].downcase.starts_with?(prefix)
          # pluck out the text from the update, cut out the @botusername part,
          # split it into an array (as summon would expect), and splat it for args to summon
          summon *update['text'][prefix.length..-1].split(' ')
          return
        end
      end
    end

    # if there's a location in the update and the sender's latest quote does not have a confirmed location
    # then add the longitude and latitude to their location (for Gwen)
    if update.key?('location') && !latest_quote.nil?
      # get the latest quote sent by this sender in this chat
      location = update['location']

      latest_quote.longitude = location['longitude']
      latest_quote.latitude = location['latitude']
      latest_quote.save
      respond_with :message, text: '🗺 A location was added to your latest quote!'
    end
  end

  # send a photo to the chat
  # uses the :photo key in the session store -- if it's not there, then they didn't send a photo
  # *args is an optional caption
  def sendphoto!(*args)
    if session.key? :photo
      new_photo = @chat.photos.new sender: from['username'], telegram_photo: session[:photo], caption: args.join(' ')

      if new_photo.save
        # prepare to download the file now that we definitely want to keep it
        file_info = bot.get_file(file_id: session[:photo])
        url = "https://api.telegram.org/file/bot#{ENV['BOT_TOKEN']}/#{file_info['result']['file_path']}"
        ext = file_info['result']['file_path'].partition('.').last

        # make a directory with this chat ID if it doesn't already exist
        dirname = Rails.root.join('telegram_images', @chat.id.to_s).to_s
        unless File.directory?(dirname)
          FileUtils.mkdir_p(dirname)
        end

        # save photo locally to /images/<chat_id>/<photo_id>.<ext> (id = the id in our database, not telegram's)
        dl_image = open(url)
        IO.copy_stream(dl_image, dirname + "/#{new_photo.id}.#{ext}")

        session.delete :photo
        respond_with :message, text: "🌄 Your photo was saved!"
      else
        respond_with :message, text: "🤬 Failed to save photo: #{new_photo.errors.full_messages} (@SamWolfson should fix this)"
      end

    else
      respond_with :message, text: "🧐 You didn't send a photo!"
    end
  end

  # shorthand for sendphoto
  def sp!(*args)
    sendphoto!(*args)
  end

  # get back a random photo that was sent to the chat
  def getphoto!(*)
    photos = @chat.photos

    if photos.empty?
      respond_with :message, text: "😭 You don't have any photos! Use /sendphoto to add some.", parse_mode: :html
    else
      photo = photos.sample
      respond_with :photo, photo: photo.telegram_photo, caption: photo.caption
    end
  end

  # shorthand for getphoto
  def gp!(*)
    getphoto!(*[])
  end

  # The format of a quote is
  # content && author && context
  # where context is optional.
  def sendquote!(*args)
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
  def sq!(*args)
    sendquote!(*args)
  end

  def getquote!(*args)
    # the sender can optionally pass the author as an argument if they only want specific authors
    author = args.join(' ').presence # returns the text if non-empty; otherwise nil

    # 10% chance of getting a Markov quote
    quote = @chat.random_quote (rand(10) > 8), author

    if quote.nil?
      respond_with :message, text: "😭 You don't have any quotes#{" by <b>#{author}</b>" if author}! Use /sendquote to add some.", parse_mode: :html
    else
      respond_with :message, text: format_quote(quote.content, quote.author, quote.context, quote.created_at.year), parse_mode: :html
    end
  end

  # shortcut method for getquote
  def gq!(*args)
    getquote!(*args)
  end

  # shortcut method for getquote and sendquote
  # if no arguments are passed, calls getquote; else calls sendquote
  def quote!(*args)
    if args.empty?
      getquote! *args
    else
      sendquote! *args
    end
  end

  # add users to the chat group
  def add!(*user_names)
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
  def remove!(*user_names)
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
  def members!
    chat_members = @chat.members.map { |m| "<b>#{m.username}</b>" }
    respond_with :message, text: "📜 Chat group members: #{chat_members.sort.to_sentence}", parse_mode: :html
  end

  # send a summon to all messages in the chat group, with an optional message
  def summon!(*message)
    chat_members = @chat.members.map { |m| "@#{m.username}" }
    chat_members.select! { |m| m !=  from['username'].downcase }

    announcement = "📣 <b>#{ if from.key? 'first_name' then from['first_name'] else from['username'] end }</b>\n"

    if message.empty?
      announcement << "\n"
    else
      announcement << message.join(' ').strip << "\n\n"
    end

    announcement << chat_members.join(', ')

    respond_with :message, text: announcement, parse_mode: :html
  end

  # shorthand for summon
  def s!(*message)
    summon! *message
  end

  def quotes!(*preferences)
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

  def on_8ball!
    answer = @chat.eight_ball_answers.sample

    if answer.nil?
      respond_with :message, text: "🤐 <i>You've got no answers, guess you're SOL.</i>", parse_mode: :html
    else
      respond_with :message, text: "<i>#{answer.answer}</i>", parse_mode: :html
    end
  end

  alias_method '8ball!', :on_8ball!

  def luck!
    response = "🍀 <b>Luck Statistics</b>\n"

    statistics = @chat.members.map do |m|
      [m.luck, m.username]
    end

    statistics.sort! do |a, b|
      b.first <=> a.first
    end

    a = statistics.map do |s|
      "<b>#{s.first}:</b> #{s.second}"
    end

    response << a.join("\n")

    respond_with :message, text: response, parse_mode: :html
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