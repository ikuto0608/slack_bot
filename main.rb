require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'mechanize'
require 'rufus-scheduler'
require 'slack-ruby-client'

DataMapper.setup(:default, "abstract::")

SLACK_TOKEN = "xxxx"
GENERAL = 'C0Y39EA4C'
RUBY_BOT = 'U1848B6SX'
IKUTO = 'U0Y3QFHPB'
MOTOKI = 'U0Y7XDM7X'
HIDETO = 'U0Y7V0FB9'
ANNA = 'U0Y7Q8K6Z'
ATABEK = 'U10CXLMJT'

class Post
  include DataMapper::Resource

  property :title, String
  property :type, String
  property :description, Text
  property :search_query, String
  property :place, String
  property :posted_at, DateTime

  def push_slack
    Slack.configure do |config|
      config.token = SLACK_TOKEN
    end
    client = Slack::Web::Client.new
    client.chat_postMessage(text: self.title, channel: GENERAL, username: "ruby", as_user: true)
  end
end

scheduler = Rufus::Scheduler.new

scheduler.cron '35 8 * * mon-fri' do
  post = Post.new
  post.title = "Our class will start now!!"
  post.push_slack
end

scheduler.cron '30 12 * * mon-fri' do
  post = Post.new
  post.title = "Our class finished, take lunch with me!!"
  post.push_slack
end

Slack.configure {|config| config.token = SLACK_TOKEN }
client = Slack::RealTime::Client.new()

client.on :message do |data|
  if data['text'].include?(RUBY_BOT) && data['subtype'] != 'bot_message'
    input_text = data['text'].downcase

    if Random.rand(10) > 7
      text = "<@#{data['user']}> How's it going, by the way?"
      client.message channel: data['channel'], text: text
      return
    end

    if input_text.include?('hi')
      text = "<@#{data['user']}> Hi, cute!"
    elsif input_text.include?('do you like me')
      num = Random.rand(10)
      if data['user'] == IKUTO
        text = "<@#{data['user']}> I love you!"
        client.message channel: data['channel'], text: text
        return
      elsif num > 8
        text = "<@#{data['user']}> I love you!"
      elsif num > 6
        text = "<@#{data['user']}> I like you!"
      elsif num > 5
        text = "<@#{data['user']}> I don't so much dislike you!"
      elsif num > 2
        text = "<@#{data['user']}> Perdon me?"
      else
        text = "<@#{data['user']}> Don't touch me!"
      end
    elsif input_text.include?('do you become my girlfriend')
      if Random.rand(10) > 4
        text = "<@#{data['user']}> I'm so sorry, you're not my favorite...!"
      else
        text = "<@#{data['user']}> Hey honey, you're already mine!"
      end
    elsif data['user'] == HIDETO or data['user'] == ATABEK
      num = Random.rand(10)
      if num > 8
        text = "<@#{data['user']}> I love your achilles tendon!"
      elsif num > 6
        text = "<@#{data['user']}> I love your coracobrachialis!"
      elsif num > 5
        text = "<@#{data['user']}> I love your fibularis brevis!"
      elsif num > 2
        text = "<@#{data['user']}> I love your biceps brachii!"
      else
        text = "<@#{data['user']}> I'm sorry, I don't know who you are.."
      end
    else
      text = "<@#{data['user']}> I'm sorry, I don't know who you are.."
    end
    client.message channel: data['channel'], text: text
  end
end

client.start!
