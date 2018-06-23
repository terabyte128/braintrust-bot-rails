require 'rails_helper'

RSpec.describe ApplicationHelpers do
  describe 'pretty_name' do
    it 'uses first and last name' do
      u = Member.new first_name: 'Firstname', last_name: 'Lastname'
      expect(pretty_name(u)).to eq('Firstname Lastname')
    end

    it 'uses first name' do
      u = Member.new first_name: 'Firstname'
      expect(pretty_name(u)).to eq('Firstname')
    end

    it 'favors full name over username' do
      u = Member.new first_name: 'Firstname', last_name: 'Lastname', username: 'auser'
      expect(pretty_name(u)).to eq('Firstname Lastname')
    end

    it 'falls back to username' do
      u = Member.new username: 'auser'
      expect(pretty_name(u)).to eq('auser')
    end

    it 'bolds names' do
      u = Member.new first_name: 'Firstname', last_name: 'Lastname', username: 'auser'
      expect(pretty_name(u, true)).to eq('<b>Firstname Lastname</b>')
    end
  end
end