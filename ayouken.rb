require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/cross_origin'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'twitter'

require_relative 'ayouken_helpers'

def init_twitter
  twitter_api = YAML.load_file( File.dirname(__FILE__) + '/../config.yml' )
  Twitter.configure do |config|
    config.consumer_key       = twitter_api["twitter_api"]["twitter_consumer_key"]
    config.consumer_secret    = twitter_api["twitter_api"]["twitter_consumer_secret"]
    config.oauth_token        = twitter_api["twitter_api"]["twitter_oauth_token"]
    config.oauth_token_secret = twitter_api["twitter_api"]["twitter_oauth_token_secret"]
  end
end

class Twitter
  def get_first_tweet(hashtag)
    res = Twitter.search("##{hashtag} -rt")
    text = res.results.map{ |t| ['@' + t.from_user, t.text].join(' ➤ ') }.first

    tiny_url = res.results.first.urls.last.url
    long_url = res.results.first.urls.last.expanded_url

    text.gsub(/#{tiny_url}/, long_url)
  end
end

module Scraping
  def scrap(uri)
    Nokogiri::HTML(open(uri
                        # ,proxy_http_basic_authentication:
                        #     [proxy_host, proxy_user, proxy_password]
                        ))
  end
end

class Gif
  include Scraping
  def initialize
    @uri = 'http://www.reddit.com/r/gifs'
  end

  def get_one
    res = scrap(@uri).css 'a.title'
    rand = Random.rand res.size
    link = res[rand]
    { title: link.content, link: link[:href] }
  end
end

class Ayouken < Sinatra::Base
  register Sinatra::CrossOrigin

  set :root, File.dirname(__FILE__)
  set :method_override, true
  set :environments, %w(production development test)
  set :environment, (ENV['RACK_ENV'] || :development).to_sym
  set :allow_origin, :any
  set :expose_headers, ['Content-Type']

  configure do
    enable :logging
    enable :cross_origin
    init_twitter
  end

  configure :development, :test do
    set :logging, Logger::DEBUG
    register Sinatra::Reloader
  end

  configure :production do
    set :logging, Logger::INFO
  end

  helpers Sinatra::Ayouken::Helpers

  def self.put_or_post(*a, &b)
    put *a, &b
    post *a, &b
  end

  not_found_json = lambda do
    json_status 404, 'Not found'
  end

  get '/' do
    json_status 200, { hello: 'world' }
  end

  get '/roulette' do
    message = rand(6) == 0 ? 'Bang!' : 'Click...'
    json_status 200, message
  end

  get '/gif' do
    json_status 200, Gif.new.get_one
  end

  get '/help' do
    list = [
      { command: 'roulette', description: '1 chance out of 6 to die' },
      { command: 'gif', description: 'Get random gif from top reddit /r/gifs' },
      { command: 'help', description: 'List of bot\'s commands' }
    ]
    json_status 200, list
  end

  get '/hashtag/:hashtag' do
    json_status 200, Twitter.get_first_tweet(params['hashtag'])
  end


  # Default handlers

  get '*', &not_found_json

  put_or_post '*', &not_found_json

  delete '*', &not_found_json

  not_found do
    not_found_json
  end

  error do
    json_status 500, env['sinatra.error'].message
  end

end
