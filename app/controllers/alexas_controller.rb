class AlexasController < ApplicationController

  # alexa does not send csrf tokens, so skip this
  skip_before_action :verify_authenticity_token, only: [ :alexa ]

  def alexa
    # alexa should send the user ID as the POST request body
    @alexa = Alexa.find_by_device_user(request.raw_post)

    if @alexa && @alexa.chat
      quote = @alexa.chat.random_quote rand(1..10) > 8, nil

      if quote
        formatted_content = quote.content.humanize
        formatted_content << '.' unless formatted_content[-1] == '.'

        response_text = "#{formatted_content}<break time='500ms'/>#{quote.author.titleize} #{quote.created_at.year}"
      else
        response_text = "You don't have any quotes in this chat yet."
      end
    else
      response_text = 'You need to register your Alexa device.'

      unless @alexa
        # create a new Alexa that can later be associated to a chat
        Alexa.create device_user: request.raw_post
      end
    end

    render json: { 'text': response_text }
  end
end
