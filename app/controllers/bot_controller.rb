class BotController < Telegram::Bot::UpdatesController
  def message(message)
    print "Got a message: #{message}"
  end
end