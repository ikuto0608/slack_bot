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

ATTTRIBUTES = ['currency-name', 'market-cap', 'price', 'volume', 'percent-24h']

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

######################
## crawl coin market
######################
def crawl_coin_market(unix_now)
  puts "crawl coin market..."
  coin_market = Nokogiri::HTML(open(ENV['COINMARKET_URL']))
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
  puts "up down check and slack it..."
  keys = redis.scan_each(:match => "*:#{unix_now}").to_a
  coin_names = keys.map{|key| key.chomp(":#{unix_now}") }
  attachments = []

  coin_names.each do |coin_name|
    coin_history_keys = redis.scan_each(:match => "#{coin_name}:*").to_a
    coin_history_keys = latest_history_keys(coin_history_keys)
    coin_histories = redis.mget(coin_history_keys).map {|coin_history| JSON.parse(coin_history) }

    latest_history = coin_histories[-1]
    latest_price = latest_history['price'].dup
    latest_price.slice!('$')
    target_history = nil
    target_price = ""
    index = -1

    happening = coin_histories[0..-2].find do |c|
      index += 1
      target_history = c
      target_price = c['price'].dup
      target_price.slice!('$')
      !((latest_price.to_f / target_price.to_f) * 100).to_i.between?(95, 105)
    end

    if happening
      parcentage = 100 - ((latest_price.to_f / target_price.to_f) * 100).to_i
      parcentage *= -1
      title = parcentage > 0 ? "is increasing." : "is reducing."
      color = parcentage > 0 ? 'good' : 'danger'
      attachments << {
        title: "#{coin_name} " + title,
        color: color,
        fields: [
        {
          title: "Coin name: #{coin_name}",
          value: "Change: #{parcentage}%",
          short: false
        },
        {
          title: "Price: #{target_history['price']}",
          value: "Date: #{Time.at(/\d{10}/.match(coin_history_keys[index]).to_s.to_i).to_datetime}",
          short: true
        },
        {
          title: "Price: #{latest_history['price']}",
          value: "Date: #{Time.at(unix_now).to_datetime}",
          short: true
        }
        ]
      }
    end
  end

  return if attachments.empty?

  client = Slack::Web::Client.new
  client.chat_postMessage(
    channel: ENV['CHANNEL'],
    as_user: true,
    attachments: attachments
  )
end

######################
## get latest redis keys
######################
def latest_history_keys(coin_history_keys)
  latest_unixtimes = coin_history_keys.map {|coin_history_key| /\d{10}/.match(coin_history_key).to_s.to_i }.sort[-12..-1]
  latest_unixtimes.map {|unixtime| coin_history_keys.select {|coin_history_key| coin_history_key.include?(unixtime.to_s) } }.flatten
end

######################
## redis instance
######################
def redis
  @redis || Redis.new
end

######################
## cron job
######################
scheduler = Rufus::Scheduler.new
# every 5 minutes
scheduler.cron '*/5 * * * *' do
  puts "Job start: #{Time.now.to_s}"
  unix_now = Time.now.to_i
  crawl_coin_market(unix_now)
  up_down_check(unix_now)
  puts "Job end: #{Time.now.to_s}"
end
