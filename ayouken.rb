require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/cross_origin'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'twitter'

require_relative 'ayouken_helpers'

def read_config
  twitter_api = YAML.load_file( File.dirname(__FILE__) + '/../config.yml' )
  Twitter.configure do |config|
    config.consumer_key       = twitter_api["twitter_api"]["twitter_consumer_key"]
    config.consumer_secret    = twitter_api["twitter_api"]["twitter_consumer_secret"]
    config.oauth_token        = twitter_api["twitter_api"]["twitter_oauth_token"]
    config.oauth_token_secret = twitter_api["twitter_api"]["twitter_oauth_token_secret"]
  end
end
read_config

class TwitterHashTag
  include Cinch::Plugin

  set :prefix, //
  match /(?:(?<=\s)|^)#(\w*[A-Za-z_]+\w*)/, method: :get_first_tweet

  def get_first_tweet(m, hashtag)
    res = Twitter.search("##{hashtag} -rt")
    text = res.results.map{ |t| ['@' + t.from_user, t.text].join(' ➤ ') }.first

    tiny_url = ''
    long_url = ''

    res.results.first.urls.map do |u|
      tiny_url = u.url
      long_url = u.expanded_url
    end

    m.reply text.gsub(/#{tiny_url}/, long_url)
  end
end

class TwitterScrap
  include Cinch::Plugin

  set :prefix, //
  match(/https:\/\/twitter.com\/(.+)\/status\/(.+)/, method: :execute_tweet)
  match(/https:\/\/twitter.com\/(.+)/,               method: :execute_account)

  def execute_tweet(m, account, id)
    url = "https://twitter.com/#{account}/status/#{id}"
    document = Nokogiri::HTML(open(url))

    tweet = document.css('.opened-tweet .tweet-text')[1]
    author = document.css('.opened-tweet .js-action-profile-name').last.content
    contains_img = false

    tweet.css('a').each do |link|
      unless link.attributes['data-expanded-url'].nil?
        link.content = link.attributes['data-expanded-url']
      end
      unless link.attributes['data-pre-embedded'].nil? # Contains an image
        link.content = link.attributes['href']
        contains_img = true
      end
    end

    m.reply((contains_img ? "[img] " : "") + "#{author}: #{tweet.text}")
  end

  def execute_account(m, account)
    url = "https://twitter.com/#{account}"
    document = Nokogiri::HTML(open(url)).css('.profile-card-inner')

    real_name_container = document.css('h1 .profile-field')
    username_container = document.css('h2 .screen-name')
    bio_container = document.css('.bio-container .bio')
    res = ""

    unless real_name_container.nil?
      res << real_name_container.first.content
    end

    unless username_container.nil?
      if real_name_container.nil?
        res << real_name_container.first.content
      else
        res << ' (' + username_container.first.content + ')'
      end
    end

    unless bio_container.nil? || bio_container.first.content.empty?
      res << ': ' + bio_container.first.content
    end

    m.reply res
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
