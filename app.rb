require 'sinatra'
require 'sinatra/reloader'
require 'json'

class Ayouken < Sinatra::Base
  set :method_override, true

  set :environments, %w(production development test)
  set :environment, (ENV['RACK_ENV'] || :development).to_sym

  configure do
    enable :logging
  end

  configure :development, :test do
    set :logging, Logger::DEBUG
    register Sinatra::Reloader
  end

  configure :production do
    set :logging, Logger::INFO
  end

  def self.put_or_post(*a, &b)
    put *a, &b
    post *a, &b
  end

  helpers do
    def json_status(code, reason)
      content_type :json
      status code
      {
        status: code,
        reason: reason
      }.to_json
    end

    def accept_params(params, *fields)
      h = {}
      fields.each do |name|
        h[name] = params[name] if params[name]
      end
      h
    end
  end

  get '/' do
    content_type :json
    { hello: 'world' }.to_json
  end

  get '/roulette' do
    content_type :json
    message = rand(6) == 0 ? 'Bang!' : 'Click...'
    { data: message }.to_json
  end

  get '/help' do
    content_type :json
    list = [
      {command: 'roulette', description: '1 chance out of 6 to die'},
      {command: 'docs', description: 'List of bot\'s commands'},
    ]
    { data: list }.to_json
  end


  # Default handlers

  get '*' do
    status 404
  end

  put_or_post '*' do
    status 404
  end

  delete '*' do
    status 404
  end

  not_found do
    json_status 404, 'Not found'
  end

  error do
    json_status 500, env['sinatra.error'].message
  end

end
