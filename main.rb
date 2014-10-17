require 'sinatra/base'
require 'active_record'
require 'json'
require 'sinatra/json'
require 'haml'
require 'digest'

require 'sinatra/reloader'

require_relative './models'

rails_env = ENV["RAILS_ENV"] ? ENV["RAILS_ENV"].to_sym : :development

ActiveRecord::Base.configurations = YAML.load_file('db/database.yml')
ActiveRecord::Base.establish_connection(rails_env)

module JSONex
  include JSON

  def self.parse_ex(source)
    begin
      JSON.parse(source)
    rescue
      false
    end
  end
end

class Hash
  def symbolize_keys
    self.each_with_object({}){ |(k, v), memo|
      memo[k.to_s.to_sym] = v
    }
  end
  def deep_symbolize_keys
    self.each_with_object({}){ |(k, v), memo|
      memo[k.to_s.to_sym] = (v.is_a?(Hash) ? v.deep_symbolize_keys : v)
    }
  end
end

class MainApp < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  enable :sessions
  set :session_secret, "f5Nb/emouGPVtSjfkdly3piqxWkX6iTC"

  get '/' do
    "hello world!"
  end

  get '/login' do
    if session[:user_id]
      redirect '/mypage'
    end

    haml :login
  end

  post '/login' do
    if session[:user_id]
      redirect "/mypage"
    end

    if users = User.where(:login_name => params[:username])
      if user[0].password_hash == params[:password_hash]
        session[:user_id] = user[0].id
        redirect "/mypage"
      else
        redirect "/login"
      end
    else
      redirect "/login"
    end
  end

  get '/mypage' do
    "loged in!"
  end

  post '/api/device', :provides => [:json] do
    posted_json = request.body.read

    unless posted_json
      halt 400, {'Content-Type' => 'text/plain'}, "No data is posted."
    end

    posted_hash = JSONex::parse_ex(posted_json).symbolize_keys

    unless posted_hash
      halt 400, {'Content-Type' => 'text/plain'}, "Posted JSON is invalid."
    end

    key_array = [:hardware_uid, :class_group_code, :class_code, :properties]

    key_array.each { |k|
      unless posted_hash.has_key?(k)
        halt 400, {'Content-Type' => 'text/plain'}, "'#{k.to_s}' is not found."
      end
    }

    # propertiesを変数に代入して、ハッシュから削除
    properties = posted_hash.delete(:properties)

    device = Device.new(posted_hash)

    unless device.save
      halt 500, {'Content-Type' => 'text/plain'}, "Failed to save devide."
    end

    h = {}

    properties.keys.each { |k|
      s = if properties[k] == "sensor"
        true
      else
        false
      end

      property = DeviceProperty.new(
        class_group_code: posted_hash[:class_group_code],
        class_code: posted_hash[:class_code],
        property_code: k.to_s,
        sensor: s
      )

      unless property.save
        halt 500, {'Content-Type' => 'text/plain'}, "Failed to save property '#{k.to_s}'."
      end

      h.store(k.to_s, property.id.to_s)
    }

    status 201
    body JSON::generate({device.id.to_s => h})
  end

  post '/api/sensor' do
    posted_json = request.body.read

    unless posted_json
      halt 400, {'Content-Type' => 'text/plain'}, "No data is posted."
    end

    posted_hash = JSONex::parse_ex(posted_json).symbolize_keys

    unless posted_hash
      halt 400, {'Content-Type' => 'text/plain'}, "Posted JSON is invalid."
    end


  end

  get '/api/sensor', :provides => [:json] do
    #if session[:user_id]
    #  redirect '/login'
    #end

    gateway_id = params[:gateway_id]


    '{"1":{"name":"ダミーセンサー","property_name":"Dummy value"}}'
  end

  post '/api/controller' do

  end

  get '/api/controller', :provides => [:json] do
    gateway_id = params[:gateway_id]

    dummy = '{"2":{"name":"ダミーコントローラー","property_name":"Dummy status",'
    dummy += '"value_range":{ "ON": "0", "OFF": "1" },"value":"1"}}'
    dummy
  end

  post '/api/monitor' do

  end

  get '/api/monitor', :provides => [:json] do
    sensor_id = params[:sensor_id]

    '{ "min": "5", "max": "30" }'
  end

  post '/api/sensor_data' do

  end

  get '/api/sensor-data', :provides => [:json] do
    sensor_id = params[:sensor_id]
    start = params[:start]
    span = params[:span] # hour daily weekly monthly yearly

    dummy = '{"2014-10-10 12:00:00":"24.6",'
    dummy += '"2014-10-10 12:00:03":"24.7",'
    dummy += '"2014-10-10 12:00:06":"24.5",'
    dummy += '"2014-10-10 12:00:09":"25.0",'
    dummy += '"2014-10-10 12:00:12":"25.2",'
    dummy += '"2014-10-10 12:00:15":"24.9",'
    dummy += '"2014-10-10 12:00:18":"25.3",'
    dummy += '"2014-10-10 12:00:21":"25.5",'
    dummy += '"2014-10-10 12:00:24":"25.2",'
    dummy += '"2014-10-10 12:00:27":"25.6"}'
    dummy
  end

  get '/api/sensor_alert', :provides => [:json] do
    sensor_id = params[:sensor_id]
    if params[:datetime]
      datetime = params[:datetime]
    else
      datetime = now
    end

    '{"alert":"1","value":"32.1","min":"5","max":"30"}'
  end

  post '/api/operation', :provides => [:json] do
    pass unless request.accept? 'application/json'

    '{ "operation_id": "1" }'
  end

  get '/api/operation', :provides => [:json] do
    gateway_id = params[:gateway_id]

    '{"2":{"operation_id":"1","value":"0"}}'
  end

  post '/api/operation_status' do

  end

  get '/api/operation_status', :provides => [:json] do
    operation_id = params[:operation_id]

    '{"value":"0","status":"0"}'
  end
end
