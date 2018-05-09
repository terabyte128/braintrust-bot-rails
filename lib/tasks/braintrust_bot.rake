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
end
