require 'rails_helper'

RSpec.describe BotController, telegram_bot: :rails do

  def create_message(uid)
    {
        from: {
            id: "99#{uid}",
            username: "uSer#{uid}"
        },
        chat: {
            id: 2468,
            title: 'TestChat'
        }
    }
  end

  # TODO test removing users
  describe 'basic functionality' do
    it 'creates a chat group and user when a message is sent' do
      message = {
          from: {
              id: 1234,
              username: 'test_user'
          },
          chat: {
              id: 2468,
              title: 'TestChat'
          }
      }
      expect { dispatch_message 'Hello', message }.to send_telegram_message(bot, /test_user was automatically added to the chat group/)

      # verify that member and chat were created
      expect(Member.where(username: 'test_user', telegram_user: '1234')).to exist
      expect(Chat.where(title: 'TestChat', telegram_chat: '2468')).to exist

      m = Chat.first.members.first

      expect(m).not_to be_nil
      expect(m.telegram_user).to eq(1234)
    end

    it 'does not add members multiple times' do
      message = {
          from: {
              id: 1234,
              username: 'test_user'
          },
          chat: {
              id: 2468,
              title: 'TestChat'
          }
      }

      10.times do |_|
        dispatch_message 'Hello', message
      end

      expect(Member.all.size).to eq(1)
      expect(Chat.all.size).to eq(1)
    end

    it 'correctly adds users without usernames' do
      message = {
          from: {
              id: 1234,
              first_name: 'foo',
              last_name: 'bar'
          },
          chat: {
              id: 2468,
              title: 'TestChat'
          }
      }

      dispatch_message 'Hello', message

      expect(Member.all.size).to eq(1)
      expect(Chat.all.size).to eq(1)

      m = Member.first
      expect(m.username).not_to be_truthy
      expect(m.first_name).to eq('foo')
      expect(m.last_name).to eq('bar')
      expect(m.chats.first.title).to eq('TestChat')
    end
  end

=begin
  describe 'add command' do
    it 'updates user information after being added with /add' do
      expect { dispatch_command "add user2", create_message(1) }.to send_telegram_message(bot, /user2(.*)was added/)

      u2 = Member.find_by_username('user2')

      expect(u2.telegram_user).to be_falsey
      expect(u2.first_name).to be_falsey
      expect(u2.last_name).to be_falsey

      u2_message = create_message(2).stringify_keys
      u2_message['from']['first_name'] = 'Firstname2'
      u2_message['from']['last_name'] = 'Lastname2'

      expect(Chat.first.members.find(u2.id)).not_to be_nil

      # should auto-update user2's information
      dispatch_message 'hello', u2_message

      u2.reload

      expect(u2.telegram_user).to eq(992)
      expect(u2.first_name).to eq('Firstname2')
      expect(u2.last_name).to eq('Lastname2')
    end
  end
=end

  describe 'summoning functionality' do

    it 'summons all users in a chat group' do
      (1..5).to_a.reverse.each do |i|
        dispatch_message 'Hello', create_message(i)
      end

      expect(Member.all.size).to eq(5)
      expect(Chat.all.size).to eq(1)

      expected_response = /#{(2..5).map {|i| "@user#{i}"}.join ', '}/

      # make sure it works with `/summon` and `/s`
      %w(summon s).each do |command|
        expect { dispatch_command command, create_message(1)}.to send_telegram_message(bot, expected_response)
      end
    end

    it 'summons when using other prefixes' do
      (1..5).to_a.reverse.each do |i|
        dispatch_message 'Hello', create_message(i)
      end

      expected_response = /#{(2..5).map {|i| "@user#{i}"}.join ', '}/

      BotController::PREFIXES.each do |prefix|
        expect { dispatch_message prefix, create_message(1)}.to send_telegram_message(bot, expected_response)
      end
    end

    it 'summons using a message' do
      expect { dispatch_command 's I am a command', create_message(1) }.to send_telegram_message(bot, /I am a command/)
    end

    it 'ignores users without usernames and sender when summoning' do
      message = {
          from: {
              id: 1234,
              first_name: 'foo',
              last_name: 'bar'
          },
          chat: {
              id: 2468,
              title: 'TestChat'
          }
      }

      dispatch_message 'Hello', message

      5.times do |i|
        dispatch_message "hello world", create_message(i)
      end

      expect { dispatch_command 's', create_message(1) }.to send_telegram_message(bot, /^[(foo)|(@user1)]/)
    end
  end

  describe 'saving quotes' do
    it 'saves quotes from new users' do
      expect { dispatch_command 'sendquote This is a test quote && Test user', create_message(1) }.to(
          send_telegram_message(bot, /Your quote was saved/)
      )

      expect(Chat.all.size).to eq(1)
      expect(Member.all.size).to eq(1)
      expect(Quote.all.size).to eq(1)

      q = Chat.first.quotes.first

      expect(q).not_to be_nil
      expect(q.content).to match(/This is a test quote/)
      expect(q.author).to match(/Test user/)
      expect(q.member).to eq(Member.first)
      expect(Member.first.quotes.first).to eq(q)
    end

    it 'saves quotes with context' do
      expect { dispatch_command 'sendquote This is a test quote && Test user && some context', create_message(1) }.to(
          send_telegram_message(bot, /Your quote was saved/)
      )

      expect(Chat.first.quotes.first.context).to match(/some context/)
    end

    it 'saves location information' do
      expect { dispatch_command 'sendquote This is a test quote && Test user', create_message(1) }.to(
          send_telegram_message(bot, /Your quote was saved/)
      )

      message = create_message(1)
      message['location'] = {
          'longitude': 100,
          'latitude': 200
      }

      expect { dispatch_message '', message }.to send_telegram_message(bot, /A location was added to your latest quote/)

      q = Chat.first.quotes.first

      expect(q.location_confirmed).to be_truthy
      expect(q.longitude).to eq(100)
      expect(q.latitude).to eq(200)

      # sanity check normal quote things
      expect(q.member).to eq(Chat.first.members.first)
      expect(q.content).to match(/This is a test quote/)
      expect(q.author).to match(/Test user/)
    end

    it 'sets confirmed for quotes with no location' do
      expect { dispatch_command 'sendquote This is a test quote && Test user', create_message(1) }.to(
          send_telegram_message(bot, /Your quote was saved/)
      )

      expect(Chat.first.quotes.first.location_confirmed).to be_falsey

      dispatch_message 'not a location', create_message(1)

      expect(Chat.first.quotes.first.location_confirmed).to be_truthy
    end

    it 'works with shorthand command /sq' do
      expect { dispatch_command 'sq This is a test quote && Test user', create_message(1) }.to(
          send_telegram_message(bot, /Your quote was saved/)
      )

      q = Chat.first.quotes.first

      expect(q.member).to eq(Chat.first.members.first)
      expect(q.content).to match(/This is a test quote/)
      expect(q.author).to match(/Test user/)
    end
  end

  describe 'retrieving quotes' do
    it 'retrieves a random quote' do
      2.times do |i|
        dispatch_command "sq test#{i} && user#{i}", create_message(2)
      end

      expect(Chat.first.quotes.size).to eq(2)

      10.times do |_|
        expect { dispatch_command 'getquote', create_message(1) }.to send_telegram_message(bot, /(test0)|(test1)/)
      end

      10.times do |_|
        expect { dispatch_command 'gq', create_message(1) }.to send_telegram_message(bot, /(test0)|(test1)/)
      end
    end

    it 'handles no quotes gracefully' do
      expect { dispatch_command 'getquote', create_message(1) }.to send_telegram_message(bot, /don't have any quotes/)
    end
  end

  describe 'sending photos' do
    it 'saves photos when no messages are sent in between' do
      message = create_message(1).stringify_keys

      msg_with_photo = message.clone

      msg_with_photo['photo'] = [
          {
              'file_size': 128,
              'file_id': 'smallerphoto'
          },
          {
              'file_size': 512,
              'file_id': 'largestphoto'
          },
          {
              'file_size': 256,
              'file_id': 'largerphoto'
          },
      ]

      dispatch_message('this is a photo', msg_with_photo)

      expect { dispatch_message '/sendphoto', message }.to send_telegram_message(bot, /Your photo was saved/)

      p = Chat.first.photos.first

      expect(p.telegram_photo).to eq('largestphoto')
      expect(Member.first.photos.first).to eq(p)
    end

    it 'discards photos when the same user sends a message in between' do
      message = create_message(1).stringify_keys

      msg_with_photo = message.clone

      msg_with_photo['photo'] = [
          {
              'file_size': 128,
              'file_id': 'smallerphoto'
          },
          {
              'file_size': 512,
              'file_id': 'largestphoto'
          },
          {
              'file_size': 256,
              'file_id': 'largerphoto'
          },
      ]

      dispatch_message('this is a photo', msg_with_photo)

      dispatch_message('this is a message in between', message)

      expect { dispatch_message '/sendphoto', message }.to send_telegram_message(bot, /You didn't send a photo/)

      expect(Chat.first.photos.size).to eq(0)
    end

    it 'preserves photos when a different user sends a message in between' do
      message = create_message(1).stringify_keys

      msg_with_photo = message.clone

      msg_with_photo['photo'] = [
          {
              'file_size': 128,
              'file_id': 'smallerphoto'
          },
          {
              'file_size': 512,
              'file_id': 'largestphoto'
          },
          {
              'file_size': 256,
              'file_id': 'largerphoto'
          },
      ]

      dispatch_message('this is a photo', msg_with_photo)

      dispatch_message('message in the way!!!', create_message(2))

      expect { dispatch_message '/sendphoto', message }.to send_telegram_message(bot, /Your photo was saved/)

      p = Chat.first.photos.first

      expect(p.telegram_photo).to eq('largestphoto')
      expect(Member.first.photos.first).to eq(p)
    end
  end

  describe 'toggling daily quotes' do
    it 'enables daily quotes' do
      expect { dispatch_command 'quotes enable' }.to send_telegram_message(bot, /Quotes enabled/)
      expect(Chat.first.quotes_enabled).to be_truthy
    end

    it 'disables daily quotes' do
      expect { dispatch_command 'quotes disable' }.to send_telegram_message(bot, /Quotes disabled/)
      expect(Chat.first.quotes_enabled).to be_falsey
    end
  end

  # TODO test 8ball, auto-adding new members as they're added to the chat (i.e. not on their first message)
end