require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/cross_origin'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'twitter'
require 'yaml'
require 'cgi'

require_relative 'ayouken_helpers'

def init_twitter
  twitter_api = YAML.load_file( 'config.yml' )
  Twitter.configure do |config|
    config.consumer_key       = twitter_api['twitter_api']['twitter_consumer_key']
    config.consumer_secret    = twitter_api['twitter_api']['twitter_consumer_secret']
    config.oauth_token        = twitter_api['twitter_api']['twitter_oauth_token']
    config.oauth_token_secret = twitter_api['twitter_api']['twitter_oauth_token_secret']
  end
end

module Scraping
  def scrap(uri)
    Nokogiri::HTML(open(uri #, proxy_http_basic_authentication:
                            #  [proxy_host, proxy_user, proxy_password]
                        ))
  end
end

class Scrapable
  include Scraping
end

class TwitterYolo
  def self.get_first_tweet(hashtag)
    res = Twitter.search("##{hashtag} -rt", count: 1).results.first

    text = "@#{res.from_user} ➤ #{res.text}"

    url = res.urls.last
    tiny_url = (defined? url.url) ? url.url : ''
    long_url = (defined? url.expanded_url) ? url.expanded_url : ''

    text.gsub /#{tiny_url}/, long_url
  end
end


class Gif
  include Scraping
  def initialize
    @uris = %w(http://www.reddit.com/r/gifs http://www.reddit.com/r/gifs/new http://www.reddit.com/r/gif/new)
  end

  def get_one
    res = scrap(@uris.sample).css 'a.title'
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

  get '/greet/:user' do
    json_status 200, "Hello #{params[:user]}"
  end

  get '/hashtag/:hashtag' do
    json_status 200, TwitterYolo.get_first_tweet(params['hashtag'])
  end

  get '/mdn/:search' do
    json_status 200, "https://developer.mozilla.org/en/search?q=#{CGI.escape(params['search'])}"
  end

  get '/google/:search' do
    query = CGI.escape(params['search'].sub('%20', ' '))
    url = "https://www.google.com/search?q=#{query}&ie=utf-8&oe=utf-8"
    document = Scrapable.new.scrap(url)
    res = document.css('li.g')
    li = res.first.content.include?('Images for') ? res[1] : res.first
    title = li.css('h3>a').first.content
    link = li.css('.s .kv cite').first.content
    unless link[0..3] == 'http'
      link = "http://#{link}"
    end
    json_status 200, "#{title} #{link} ( #{url} )"
  end

  get '/help' do
    list = [
      { command: 'gif', description: 'Get random gif from top reddit /r/gifs' },
      { command: 'greet [username]', description: 'Greet someone' },
      { command: 'google [query]', description: 'Get link to Google query' },
      { command: 'hashtag [hashtag]', description: 'First Twitter result of the hashtag' },
      { command: 'help', description: "List of bot's commands" },
      { command: 'mdn [query]', description: 'Search on Mozilla Developer Network' },
      { command: 'roulette', description: '1 chance out of 6 to die' }
    ]
    json_status 200, list
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
