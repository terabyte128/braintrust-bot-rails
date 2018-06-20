require "#{Rails.root}/lib/helpers/application_helpers"
include ApplicationHelpers

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
          formatted = format_quote(quote.content, quote.author, quote.context, quote.created_at.year)
          bot.send_message chat_id: chat.telegram_chat, text: formatted, parse_mode: :html
        end
      end
    end

    send_quote
  end

  desc "Change luck for each person"
  task change_luck: :environment do
    Member.all.each do |m|
      if rand(6) == 0
        m.luck = rand(101)
        m.save
      end
    end
  end

  desc "Import database entries from BrainTrust Bot 1.0"
  task import_old_database: :environment do
    DATABASE_NAME = 'btb_corpus'
    FILE_PATH = "Rails.root.join('tmp')/temp.csv"

    def command(table)
      "psql -c \"COPY (SELECT * FROM #{table}) TO '#{FILE_PATH}' WITH CSV DELIMITER '|';\" #{DATABASE_NAME}"
    end

    def try_delete
      File.delete FILE_PATH if File.exist?(FILE_PATH)
    end

    def process_file
      File.open(FILE_PATH) do |f|
        f.each_line do |line|
          splat = line.split '|'
          yield(splat)
        end
      end
    end

    # chats
    try_delete
    system command('braintrust_bot_quotechat')
    process_file do |tokens|
      Chat.create! telegram_chat: tokens[1], quotes_enabled: tokens[2] == 't'
    end

    # quotes
    try_delete
    system command('braintrust_bot_chatmember')
    process_file do |tokens|
      chat = Chat.where(telegram_chat: tokens[2]).first_or_create!
      chat.members.create! username: tokens[1]
    end

    try_delete
    system command('braintrust_bot_quotestorage')
    process_file do |tokens|
      chat = Chat.where(telegram_chat: tokens[1]).first_or_create!
      quote = chat.quotes.new content: tokens[2],
                              author: tokens[4],
                              created_at: DateTime.new(tokens[5])

      quote.sender = tokens[7] if tokens[7].present?
      quote.context = tokens[3] if tokens[3].present?

      quote.save!
    end

    try_delete
    system command('braintrust_bot_photo')
    process_file do |tokens|
      chat = Chat.where(telegram_chat: tokens[1]).first_or_create!
      # photo = chat.photos.new telegram_photo: tokens[5],


    end
  end
end
