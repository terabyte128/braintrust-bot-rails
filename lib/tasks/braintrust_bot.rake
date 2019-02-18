require "#{Rails.root}/lib/helpers/application_helpers"
include ApplicationHelpers
require 'csv'
require 'json'

namespace :braintrust_bot do
  desc "Send a quote to all chats that request a quote every day (with 1/3 probability)"
  task send_quote: :environment do
    bot = Telegram::Bot::Client.new(ENV['BOT_TOKEN'], ENV['BOT_NAME'])

    dice = [false] * 2 + [true]
    send_quote = dice.sample

    Chat.where(quotes_enabled: true).each do |chat|
      if dice.sample
        quote = chat.quotes.sample

        unless quote.nil?
          quote.increment! :times_accessed
          bot.send_message chat_id: chat.telegram_chat, text: quote.format, parse_mode: :html
        end
      end
    end

    send_quote
  end

  desc "Change luck for each person"
  task change_luck: :environment do
    Member.all.each do |m|
      if rand(6) == 1
        m.update_luck_random
      end
    end
  end

  task notify_birthdays: :environment do
    today_date = DateTime.now.to_date
    week_from_now_date = 7.days.from_now.to_date

    bot = Telegram::Bot::Client.new(ENV['BOT_TOKEN'], ENV['BOT_NAME'])

    def age(user)
      ((DateTime.now.to_date - user.birthday) / 365).to_i
    end

    def today_sentence(user)
      "#{user.display_name(true)} turns <b>#{age(user)}</b> today! Happy birthday, #{user.display_name(true)}!"
    end

    def next_week_sentence(user)
      "#{user.display_name(true)} turns <b>#{age(user) + 1}</b> next week!"
    end

    Chat.where(birthdays_enabled: true).each do |chat|

      chat.members.each do |member|
        unless (birthday = member.birthday) == nil
          if birthday.day == week_from_now_date.day && birthday.month == week_from_now_date.month
            bot.send_message chat_id: chat.telegram_chat, text: "🎂 #{next_week_sentence(member)}".strip, parse_mode: :html
          elsif birthday.day == today_date.day && birthday.month == today_date.month
            bot.send_message chat_id: chat.telegram_chat, text: "🎂 #{today_sentence(member)}".strip, parse_mode: :html
          end
        end
      end
    end
  end

  desc "Import database entries from BrainTrust Bot 1.0"
  task import_old_database: :environment do
    DATABASE_NAME = ENV['OLD_DB']
    FILE_PATH = "/tmp/temp.csv"

    def command(table)
      "psql -c \"COPY (SELECT * FROM #{table}) TO STDOUT WITH CSV DELIMITER '|';\" #{DATABASE_NAME} > #{FILE_PATH}"
    end

    puts "using command #{command('example_table')}"

    def try_delete
      File.delete FILE_PATH if File.exist?(FILE_PATH)
    end

    def process_file
      CSV.foreach(FILE_PATH, col_sep: '|') do |row|
        yield(row)
      end
    end

    # chats
    try_delete
    system command('braintrust_bot_quotechat')
    process_file do |tokens|
      puts "adding chat #{tokens}"
      Chat.create! telegram_chat: tokens[1], quotes_enabled: tokens[2] == 't'
    end

    # quotes
    try_delete
    system command('braintrust_bot_chatmember')
    process_file do |tokens|
      puts "adding member #{tokens}"

      chat = Chat.where(telegram_chat: tokens[2]).first_or_create!
      member = Member.where(username: tokens[1].downcase).first_or_create!

      unless member.chats.include?(chat)
        member.chats << chat
      end
    end

    try_delete
    system command('braintrust_bot_quotestorage')
    process_file do |tokens|
      puts "adding quote #{tokens}"
      chat = Chat.where(telegram_chat: tokens[1]).first_or_create!
      quote = chat.quotes.new content: tokens[2],
                              author: tokens[4],
                              created_at: DateTime.parse(tokens[5]),
                              location_confirmed: true

      # sender
      if tokens[7].present?
        sender = Member.where(username: tokens[7].downcase).first_or_create!

        quote.member = sender

        unless sender.chats.include?(chat)
          sender.chats << chat
        end
      end

      quote.context = tokens[3] if tokens[3].present?

      quote.save!
    end

    try_delete
    system command('braintrust_bot_photo')
    process_file do |tokens|
      # skip unconfirmed photos
      next unless tokens[6] == "t"

      puts "adding photo #{tokens}"

      chat = Chat.where(telegram_chat: tokens[1]).first_or_create!

      p = chat.photos.new telegram_photo: tokens[5],
                          created_at: DateTime.parse(tokens[4])

      if tokens[7].present?
        sender = Member.where(username: tokens[7].downcase).first_or_create!
        p.member = sender

        unless sender.chats.include?(chat)
          sender.chats << chat
        end
      end

      if tokens[2].present?
        p.caption = tokens[2]
      end

      p.save!
    end

    try_delete
    system command('braintrust_bot_eightballanswer')
    process_file do |tokens|
      puts "adding 8 ball answer #{tokens}"

      chat = Chat.where(telegram_chat: tokens[2]).first_or_create!
      chat.eight_ball_answers.create! answer: tokens[1]
    end

    try_delete
  end

  desc "Download photos from Telegram"
  task download_photos: :environment do
    bot = Telegram::Bot::Client.new(ENV['BOT_TOKEN'])

    Chat.all.each do |chat|
      chat.photos.all.each do |photo|
        puts "downloading photo #{photo.id}"

        dirname = Rails.root.join('telegram_images', chat.id.to_s).to_s

        # skip already saved photos
        next unless Dir.glob(dirname + "/#{photo.id}*").empty?

        # prepare to download the file
        file_info = bot.get_file(file_id: photo.telegram_photo)

        puts "got file info: #{file_info}"

        url = "https://api.telegram.org/file/bot#{ENV['BOT_TOKEN']}/#{file_info['result']['file_path']}"
        ext = file_info['result']['file_path'].partition('.').last

        ext = "jpg" unless ext.present?

        # make a directory with this chat ID if it doesn't already exist
        unless File.directory?(dirname)
          FileUtils.mkdir_p(dirname)
        end

        # save photo locally to /images/<chat_id>/<photo_id>.<ext> (id = the id in our database, not telegram's)
        dl_image = open(url)
        IO.copy_stream(dl_image, dirname + "/#{photo.id}.#{ext}")
      end
    end
  end

  desc 'Import messages from Telegram'
  task :import_telegram_messages, [:file] => [:environment] do |task, args|
    file = File.open(args[:file])
    data = JSON.parse(file.read)

    data['chats']['list'].each do |chat|
      puts "trying to import messages for #{chat['name']} (  #{chat['id']}  )"
      # truncate to a 32 bit integer and negate it
      truncated_id = chat['id'].to_s(2)[-32..-1].to_i(2) * -1

      puts truncated_id

      if (my_chat = Chat.find_by telegram_chat: truncated_id)

        chat['messages'].each do |message|
          if (member = Member.find_by telegram_user: message['from_id']) && message.dig('text')
            my_chat.messages.create! member: member,
                                     telegram_message: message['id'],
                                     created_at: message['date'],
                                     content: message['text']
            puts "imported #{message['text']}"
          end
        end

        puts "imported messages for #{chat['title']}"
      end
    end
  end
end
