require 'rails_helper'

RSpec.describe AlexasController, type: :controller do
  describe 'responds to requests from Alexa' do
    it 'creates an unassigned Alexa object with the user' do
      post :alexa, body: 'alexa1234'
      expect(response.content_type).to eq('application/json')

      response_hash = JSON.parse(response.body)
      expect(response_hash).to include "text" => match(/register/)

      expect(Alexa.all.size).to eq 1
      expect(Alexa.first.device_user).to eq 'alexa1234'
      expect(Alexa.first.chat_id).to be_nil
    end

    it 'does not add Alexa multiple times' do
      post :alexa, body: 'alexa1234'
      expect(response.content_type).to eq('application/json')

      response_hash = JSON.parse(response.body)
      expect(response_hash).to include "text" => match(/register/)

      expect(Alexa.all.size).to eq 1
      expect(Alexa.first.device_user).to eq 'alexa1234'
      expect(Alexa.first.chat_id).to be_nil

      post :alexa, body: 'alexa1234'
      expect(response.content_type).to eq('application/json')

      response_hash = JSON.parse(response.body)
      expect(response_hash).to include "text" => match(/register/)

      expect(Alexa.all.size).to eq 1
      expect(Alexa.first.device_user).to eq 'alexa1234'
      expect(Alexa.first.chat_id).to be_nil
    end

    it 'returns an error from an associated chat with no quotes' do
      a = Alexa.create device_user: 'alexa1234'
      c = Chat.create telegram_chat: '2468'

      a.update_attribute :chat, c

      expect(a.chat).to eq(c)

      post :alexa, body: 'alexa1234'

      response_hash = JSON.parse(response.body)
      expect(response_hash).to include "text" => match(/don't have any quotes/)
    end

    it 'returns a quote from an associated chat with quotes' do
      a = Alexa.create! device_user: 'alexa1234'
      c = Chat.create! telegram_chat: '2468'
      m = c.members.create! username: 'test'

      q = c.quotes.create! content: 'content', author: 'author', member: m

      a.update_attribute :chat, c

      expect(a.chat).to eq(c)

      post :alexa, body: 'alexa1234'

      response_hash = JSON.parse(response.body)
      expect(response_hash).to include "text"

      expect(response_hash['text']).to eq "#{q.content.humanize}.<break time='500ms'/>#{q.author.titleize} #{q.created_at.year}"
    end
  end
end