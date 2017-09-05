require 'bundler'
Bundler.require
require 'dotenv/load'

require './main'
run Sinatra::Application
