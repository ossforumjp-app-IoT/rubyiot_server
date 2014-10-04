require "sinatra/base"
require "sinatra/json"
require "active_record"
require "haml"
require "digest"

require_relative "models"

class MainApp < Sinatra::Base
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

  get '/api/sensor' do
    #if session[:user_id]
    #  redirect '/login'
    #end


  end
end
