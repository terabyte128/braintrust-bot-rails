require "#{Rails.root}/lib/helpers/application_helpers"
require 'open-uri'
require 'fileutils'
include ApplicationHelpers

class BotController < Telegram::Bot::UpdatesController

  PREFIXES = %w(@channel @everyone @all @people)
  PREFIXES << "@#{Telegram.bot.username.downcase}" if Telegram.bot.username.present?
  SUMMON_GROUP_SIZE = 5

  before_action :find_or_create_chat, :find_or_create_user, :add_members, :remove_member

  use_session!

  def message(update)
    return if @user.nil?

    session.delete :photo

    # assume that the next message they send means they don't want to add location (unless that message is a location)
    latest_quote = @user.quotes.order(created_at: :desc).where(location_confirmed: false, chat: @chat).first

    unless latest_quote.nil?
      latest_quote.update_attribute :location_confirmed, true
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
      PREFIXES.each do |prefix|
        if update['text'].downcase.starts_with?(prefix)
          # pluck out the text from the update, cut out the @botusername part,
          # split it into an array (as summon would expect), and splat it for args to summon
          summon! *update['text'][prefix.length..-1].split(' ')
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

  def luckstats!(*args)
    return if @user.nil?

    if args.size != 1
      respond_with :message, text: "😈 Usage: /luckstats [username]"
      return
    end

    if (target = @chat.members.find_by_username(strip_leading_at(args[0]).downcase))
      path = Rails.application.routes.url_helpers.chat_statistics_url(chat_id: @chat.id, member: target.id)
      response = "🔗 <a href=\"#{path}#luck\">Luck Statistics for #{target.display_name(false)}</a>"
      respond_with :message, text: response, parse_mode: :html
    else
      respond_with :message, text: "🤷‍♂️ That user doesn't exist in this chat!"
    end
  end

  def chatstats!(*args)
    return if @chat.nil?

    path = Rails.application.routes.url_helpers.chat_statistics_url(chat_id: @chat.id)
    response = "🔗 <a href=\"#{path}\">Chat Statistics for #{@chat.display_name}</a>"
    respond_with :message, text: response, parse_mode: :html
  end

  # send a photo to the chat
  # uses the :photo key in the session store -- if it's not there, then they didn't send a photo
  # *args is an optional caption
  def sendphoto!(*args)
    return if @user.nil?

    if session.key? :photo
      new_photo = @chat.photos.new member: @user, telegram_photo: session[:photo], caption: args.join(' ')

      if new_photo.save
        cached_response = respond_with :message, text: "🌄 Your photo is being saved..."

        # since this involves downloading a real photo from Telegram, it's not really something we can test...
        unless Rails.env == 'test'
          # prepare to download the file now that we definitely want to keep it
          file_info = bot.get_file(file_id: session[:photo])
          url = "https://api.telegram.org/file/bot#{ENV['BOT_TOKEN']}/#{file_info['result']['file_path']}"
          ext = file_info['result']['file_path'].partition('.').last

          ext = "jpg" unless ext.present?

          # make a directory with this chat ID if it doesn't already exist
          dirname = Rails.root.join('telegram_images', @chat.id.to_s).to_s
          unless File.directory?(dirname)
            FileUtils.mkdir_p(dirname)
          end

          # save photo locally to /images/<chat_id>/<photo_id>.<ext> (id = the id in our database, not telegram's)
          dl_image = open(url)
          IO.copy_stream(dl_image, dirname + "/#{new_photo.id}.#{ext}")

          bot.public_send('edit_message_text', text: "🌄 Your photo was saved!",
                          chat_id: cached_response['result']['chat']['id'],
                          message_id: cached_response['result']['message_id'])
        end

        session.delete :photo
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
      photo = photos.sample.increment! :times_accessed
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
    return if @user.nil?

    # the sender wants to save a quote sent in the chat by someone else
    if update.dig('message', 'reply_to_message')
      original_message = update['message']['reply_to_message']
      new_quote = @chat.quotes.new content: original_message['text']

      if original_message['from']['first_name']
        new_quote.author = original_message['from']['first_name']
        if original_message['from']['last_name']
          new_quote.author ||= ""
          new_quote.author << " #{original_message['from']['last_name']}"
        end
      elsif original_message['from']['username']
        new_quote.author = original_message['from']['username']
      else
        new_quote.author = "???"
      end
    else

      # tokenize the quote into content, author, and (optional) context
      tokens = args.join(' ').split('&&')

      # we need either 2 or 3 tokens for a valid quote
      unless tokens.length.between?(2, 3)
        respond_with :message, text: "🧐 Usage: /sendquote [quote] && [author] && [optional context]"
        return
      end

      tokens.map! { |t| t.strip } # remove leading and trailing whitespace
      new_quote = @chat.quotes.new content: tokens[0], author: tokens[1], member: @user

      if tokens.length == 3
        new_quote.context = tokens[2]
      end
    end


    if new_quote.save
      respond_with :message, text: '👌 Your quote was saved!'
    else
      respond_with :message, text: "🤬 Failed to save quote: [#{new_quote.errors.full_messages.join(", ")}] (@SamWolfson should fix this)"
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
      respond_with :message, text: quote.format, parse_mode: :html
    end
  end

  # shortcut method for getquote
  def gq!(*args)
    getquote!(*args)
  end

  # shortcut method for getquote and sendquote
  # if no arguments are passed and it's not a reply to a different message, calls getquote;
  # else calls sendquote
  def quote!(*args)
    if args.empty? && !update.dig('message', 'reply_to_message')
      getquote! *args
    else
      sendquote! *args
    end
  end

  # get all members in the chat group
  def members!
    chat_members = @chat.members.map { |m| "#{m.display_name(true)}" }
    respond_with :message, text: "📜 Chat group members: #{chat_members.sort.to_sentence}", parse_mode: :html
  end

  # send a summon to all messages in the chat group, with an optional message
  def summon!(*message)
    if @user
      @user.chat_members.find_by_chat_id(@chat.id).increment! :summons_performed
    end

    chat_members = @chat.members
                       .select { |m| m.telegram_user != from['id'] }
                       .map { |m| m.username.nil? ? m.html_link : "@#{m.username}" }
                       .sort

    announcement = "📣 <b>#{ if from.key? 'first_name' then from['first_name'] else from['username'] end }</b>\n"

    if message.empty?
      announcement << "\n"
    else
      announcement << message.join(' ').strip << "\n\n"
    end

    chat_members.in_groups_of(SUMMON_GROUP_SIZE, false).each do |group|
      respond_with :message, text: group.join(", ")
    end

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

  def on_8ball!(*)
    answer = @chat.eight_ball_answers.sample
    reply_to_message = update['message']['message_id']

    if answer.nil?
      respond_with :message, text: "🤐 <i>You've got no answers, guess you're SOL.</i>", parse_mode: :html,
                   reply_to_message_id: reply_to_message
    elsif answer.telegram_sticker
      respond_with :sticker, sticker: answer.telegram_sticker, reply_to_message_id: reply_to_message
    else
      respond_with :message, text: "<i>#{answer.answer}</i>", parse_mode: :html, reply_to_message_id: reply_to_message
    end
  end

  alias_method '8ball!', :on_8ball!

  def luck!
    response = "🍀 <b>Luck Statistics</b>\n"

    statistics = @chat.members.map do |m|
      # grab the luck right before the current one
      latest_lucks = m.luck_histories.order(created_at: :desc)
      current = latest_lucks.first
      before = latest_lucks.second

      if current && current.created_at > 1.day.ago && before
        [m.luck, m.display_name, m.luck - before.luck]
      else
        [m.luck, m.display_name, nil]
      end
    end

    statistics.sort! do |a, b|
      # sort by amount of luck, then username
      b.first == a.first ?
          a.second <=> b.second : b.first <=> a.first
    end

    sum = 0
    luck_delta = 0

    a = statistics.map do |s|
      if s.third
        history = "("
        if s.third < 0
          history << "👇"
        elsif s.third == 0
          history << "🤷‍"
        else
          history << "👆"
        end
        history << s.third.abs.to_s
        history << ")"
      else
        history = ""
      end

      luck_delta += s.third if s.third
      sum += s.first
      "<b>#{s.first}:</b> #{s.second} #{history}"
    end

    response << a.join("\n")
    response << "\n🎲 Average: #{(sum.to_f / statistics.size).round(1)}"

    avg_delta = (luck_delta.to_f / statistics.size).round 1

    if luck_delta > 0
      response << " (👆#{(avg_delta.abs)})"
    elsif luck_delta < 0
      response << " (👇#{(avg_delta.abs)})"
    end

    respond_with :message, text: response, parse_mode: :html
  end

  def birthday!(*args)
    return if @user.nil?
    reply_to_message = update['message']['message_id']

    if args.size == 0
      if @user.birthday.nil?
        respond_with :message, text: "🧐 You haven't set a birthday yet. Try: /birthday [your birthday]",
                     reply_to_message_id: reply_to_message
      else
        respond_with :message, text: "🎂 Your birthday is <b>#{@user.birthday.strftime("%-d %b %Y")}</b>.",
                     parse_mode: :html, reply_to_message_id: reply_to_message
      end
    else
      strargs = args.join(" ")
      begin
        date = strargs.to_date
        @user.update_attribute :birthday, date
        respond_with :message, text: "🎂 Your birthday was set to <b>#{date.strftime("%-d %b %Y")}</b>.",
                     parse_mode: :html, reply_to_message_id: reply_to_message
      rescue ArgumentError
        respond_with :message, text: "🤷‍♀️ I couldn't parse <b>#{strargs}</b> as a date.", parse_mode: :html,
                     reply_to_message_id: reply_to_message
      end
    end
  end

  def planepic!(*)
    queries = %w(airplane plane 737 747 a380 boeing airbus bombardier)
    webpic!(queries.sample)
  end

  def webpic!(*args)
    cached_response = respond_with :message, text: "🕵🏻‍♀️ Looking up a picture for you...", parse_mode: :markdown
    begin
    photo = Unsplash::Photo.random(query: args.join(" "))

    # This attribution format is required by the Unsplash API.
    # The first letter is a direct link to the photo so that telegram will load a preview.
    # The rest is a link to the photo's "page" with other info about it.
    caption = "[P](#{photo[:urls][:regular]})[hoto](#{photo[:links][:html]})"
    caption << " by [#{photo[:user][:name]}](#{photo[:user][:links][:html]})"
    caption << " on [Unsplash](https://unsplash.com)"

    bot.public_send('edit_message_text', text: caption,
                    chat_id: cached_response['result']['chat']['id'],
                    message_id: cached_response['result']['message_id'], parse_mode: :markdown)
    rescue Unsplash::Error, JSON::ParserError
      bot.public_send('edit_message_text', text: "🤷‍♀️ I couldn't find anything that matched <b>#{args.join(" ")}</b>.‍",
                      chat_id: cached_response['result']['chat']['id'],
                      message_id: cached_response['result']['message_id'], parse_mode: :html)
    end
  end


  private


  def find_or_create_chat
    @chat = Chat.where(telegram_chat: chat['id']).first_or_create

    # update title if necessary
    @chat.update_attribute :title, chat[:title]
  end

  # if the message contains newly added chat members, then add them to the chat automatically
  def add_members
    if update.dig('message', 'new_chat_members')
      added = []

      update['message']['new_chat_members'].each do |m|
        next if m['is_bot']

        new_member = Member.find_by_telegram_user m['id']
        new_member ||= Member.find_by_username m['username'].downcase if m['username'].present?
        new_member ||= Member.new telegram_user: m['id']

        new_member.first_name = m['first_name'] if m['first_name'].present?
        new_member.last_name = m['last_name'] if m['last_name'].present?
        new_member.username = m['username'].downcase if m['username'].present?

        unless new_member.chats.include?(@chat.id)
          new_member.chats << @chat
        end

        new_member.save!
        added << new_member
      end

      unless added.empty?
        pretty_users = added.map { |u| u.display_name(true) }
        message = "#{added.size == 1 ? 'was' : 'were'} added to the chat group."

        respond_with :message, text: "❤️ #{pretty_users.to_sentence} #{message}", parse_mode: :html
      end
    end
  end

  # if the message contains removed members, then remove them
  def remove_member
    if update.dig('message', 'left_chat_member')
      left = update['message']['left_chat_member']

      return if left['is_bot']

      member = @chat.members.find_by_telegram_user left['id']
      member ||= @chat.members.find_by_username left['username'].downcase

      unless member.nil?
        @chat.members.delete member
        respond_with :message, text: "💔 #{member.display_name(true)} was removed from the chat group.", parse_mode: :html
      end
    end
  end

  # check the sender of each message to see whether they're part of this chat group.
  # if not, create the user as necessary and add them
  def find_or_create_user
    if from['is_bot']
      @user = nil
      return
    end

    # try and find by ID
    @user = Member.find_by_telegram_user from['id']

    if @user.nil?
      # try and find by username
      @user = Member.find_by_username from['username'].downcase if from['username'].present?

      if @user.nil?
        @user = Member.new telegram_user: from['id']
      else
        # update their ID to match
        @user.telegram_user = from['id']
      end
    end

    # update their username and first/last names because we know their ID (always stay up to date!)
    @user.username = from['username'].downcase if from['username'].present?
    @user.first_name = from['first_name'] if from['first_name'].present?
    @user.last_name = from['last_name'] if from['last_name'].present?

    # add new members automatically
    unless @user.chats.exists?(@chat.id)
      @user.chats << @chat
      response = "❤️ #{@user.display_name(true)} was added to the chat group."

      respond_with(:message, text: response, parse_mode: :html)
    end

    unless @user.save
      respond_with :message, text: "⚠️ Failed to update #{from['username']}. (#{@user.errors.full_messages})"
    end
  end

  def strip_leading_at(username)
    if username.start_with? '@'
      username[1..-1]
    else
      username
    end
  end
end
