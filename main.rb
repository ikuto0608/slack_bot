require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'mechanize'
require 'rufus-scheduler'
require 'slack-ruby-client'
require "redis"

COINMARKET_URL = ENV['COINMARKET_URL']
ATTTRIBUTES = ['currency-name', 'market-cap', 'price', 'volume', 'percent-24h']

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

######################
## crawl coin market
######################
def crawl_coin_market(unix_now)
  coin_market = Nokogiri::HTML(open(COINMARKET_URL))
  rows = coin_market.xpath('//table/tbody/tr')
  rows.each do |row|
    coin_hash = ATTTRIBUTES.inject({}) do |hash, attribute|
      hash.merge!(
        { "#{attribute.gsub('-', '_')}".to_sym => row.at_css('.' + attribute).text.strip }
      )
      hash
    end

    redis.set("#{coin_hash[:currency_name]}:#{unix_now}", coin_hash.to_json)
  end
end

######################
## up down check and slack it
######################
def up_down_check(unix_now)
  keys = redis.scan_each(:match => "*:#{unix_now}").to_a
  coin_names = keys.map{|key| key.chomp(":#{unix_now}") }

  coin_names.each do |coin_name|
    coin_history_keys = redis.scan_each(:match => "#{coin_name}:*").to_a
    coin_history_keys = latest_history_keys(coin_history_keys)
    coin_histories = redis.mget(coin_history_keys).map {|coin_history| JSON.parse(coin_history) }

    latest_history = coin_histories[-1]
    happening = coin_histories[0..-2].find do |c|
      latest = latest_history['price']
      latest.slice!('$')
      current = c['price']
      current.slice!('$')
      !((latest.to_f / current.to_f) * 100).to_i.between?(95, 105)
    end

    if happening
      client = Slack::Web::Client.new
      client.chat_postMessage(
        channel: ENV['HOGE_CHANNEL'],
        as_user: true,
        attachments: [{
          pretext: "It's happening!",
				  title: "#{coin_name} has changed.",
				  color: 'good',
				  fields: [
          {
            title: "#{coin_name}",
            value: "",
            short: false
          },
          {
            title: latest_history['price'],
            value: Time.at(unix_now).to_datetime,
            short: true
          },
          {
            title: "",
            value: "",
            short: true
          }
				  ]
        }]
      )
    end
  end
end

def latest_history_keys(coin_history_keys)
  latest_unixtimes = coin_history_keys.map {|coin_history_key| /\d{10}/.match(coin_history_key).to_s.to_i }.sort[-12..-1]
  latest_unixtimes.map {|unixtime| coin_history_keys.select {|coin_history_key| coin_history_key.include?(unixtime.to_s) } }.flatten
end

def redis
  @redis || Redis.new
end

######################
## cron job
######################
scheduler = Rufus::Scheduler.new
# every 5 minutes
scheduler.cron '*/5 * * * *' do
  unix_now = Time.now.to_i
  crawl_coin_market(unix_now)
  up_down_check(unix_now)
end
