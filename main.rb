require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'slack'
require 'mechanize'
require 'rufus-scheduler'

DataMapper.setup(:default, "abstract::")

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
      config.token = 'xxxxxxx'
    end
    Slack.chat_postMessage(text: self.title, channel: 'xxxxx')
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
