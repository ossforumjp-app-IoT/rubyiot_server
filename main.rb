require 'sinatra/base'
require 'sinatra/json'
require 'active_record'
require 'haml'
require 'digest'

require 'sinatra/reloader'

require_relative './models'

ActiveRecord::Base.configurations = YAML.load_file('db/database.yml')
ActiveRecord::Base.establish_connection('development')

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
    pass unless request.accept? 'application/json'

    '{"1":{"0xB0":"3"}}'
  end

  post '/api/sensor' do

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
