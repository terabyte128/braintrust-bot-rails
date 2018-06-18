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
    Chat.all.each do |chat|
      chat.members.each do |m|
        if rand(6) == 0
          m.luck = rand(101)
          m.save
        end
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

    # chats
    try_delete
    system command('braintrust_bot_quotechat')

    File.open(FILE_PATH) do |f|
      f.each_line do |line|
        splat = line.split '|'
        chat = Chat.new telegram_chat: splat[1], quotes_enabled: splat[2] == 't'
        chat.save
      end
    end

    # quotes
    try_delete
    system command('braintrust_bot_')

  end
end
