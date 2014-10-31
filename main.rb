require 'sinatra/base'
require 'active_record'
require 'json'
require 'sinatra/json'
require 'haml'
require 'digest'
require 'bigdecimal'

require 'sinatra/reloader'

require_relative './models'

rails_env = ENV["RAILS_ENV"] ? ENV["RAILS_ENV"].to_sym : :development

ActiveRecord::Base.configurations = YAML.load_file('db/database.yml')
ActiveRecord::Base.establish_connection(rails_env)

TEXT_PLAIN = { 'Content-Type' => 'text/plain' }

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

  post '/api/:type', :provides => [:text] do
    posted_json = request.body.read

    if posted_json.length == 0
      halt 400, TEXT_PLAIN, "No data is posted."
    end

    posted_hash = JSONex::parse_ex(posted_json)

    unless posted_hash
      halt 400, TEXT_PLAIN, "Posted JSON is invalid."
    end

    return_value = case params[:type]
    when "sensor_data"
      sensor_data(posted_hash)
    when "operation"
      operation(posted_hash)
    when "operation_status"
      operation_status(posted_hash)
    when "device"
      device(posted_hash)
    when "sensor", "controller"
      device_property(posted_hash)
    when "monitor"
      monitor(posted_hash)
    else
      halt 404, TEXT_PLAIN, "Not Found"
    end

    status 201
    body return_value
  end

  get '/api/sensor', :provides => [:json] do
    if params[:gateway_id]
      gateway_id = params[:gateway_id]
    else
      halt 400, TEXT_PLAIN, "Parameter gateway_id is needed."
    end

    objs = DeviceProperty.where(gateway_id: gateway_id, sensor: true)
    return_hash = {}

    objs.each { |obj|
      maxid = SensorData.where(device_property_id: obj.id).maximum(:id)
      d = maxid ? SensorData.find(maxid) : nil

      if d
        v = magnify(obj.id, d.value)
        dt = d.measured_at.strftime("%Y-%m-%d %H:%M:%S")
        a = if SensorAlert.where("device_property_id = ? AND measured_at >= ?",
          obj.id, dt - 30).exists?
          "1"
        else
          "0"
        end
      else
        v = ""
        dt = ""
        a = "0"
      end

      h = {
        obj.id.to_s => {
          "name" => obj.name,
          "property_name" => obj.property_name,
          "device_id" => obj.device_id.to_s,
          "value" => v,
          "datetime" => dt,
          "alert" => a
        }
      }

      return_hash = return_hash.merge(h)
    }

    JSON::generate(return_hash)
    #'{"1":{"name":"ダミーセンサー","property_name":"Dummy value","device_id":"1","value":"25","datetime":"2014-10-25 12:00:00","alert":"0"}}'
  end

  get '/api/controller', :provides => [:json] do
    if params[:gateway_id]
      gateway_id = params[:gateway_id]
    else
      halt 400, TEXT_PLAIN, "Parameter gateway_id is needed."
    end

    objs = DeviceProperty.where(gateway_id: gateway_id, sensor: false)
    return_hash = {}

    objs.each { |obj|
      maxid = Operation.where(device_property_id: obj.id, status: 0).maximum(:id)
      v = maxid ? Operation.find(maxid).value : "1"

      h = {
        obj.id.to_s => {
          "name" => obj.name,
          "property_name" => obj.property_name,
          "value_range" => obj.definitions("value_range"),
          "value" => v,
          "device_id" => obj.device_id.to_s
        }
      }

      return_hash = return_hash.merge(h)
    }

    JSON::generate(return_hash)
  end

  get '/api/monitor', :provides => [:json] do
    if params[:sensor_id]
      sensor_id = params[:sensor_id]
    else
      halt 400, TEXT_PLAIN, "Parameter sensor_id is needed."
    end

    objs = MonitorRange.where(device_property_id: sensor_id.to_i)

    return_hash = if objs.length > 0
      {
        "min" => magnify(sensor_id.to_i, objs[0].min_value),
        "max" => magnify(sensor_id.to_i, objs[0].max_value)
      }
    else
      { "min" => "", "max" => "" }
    end

    JSON::generate(return_hash)
  end

  get '/api/sensor_data', :provides => [:json] do
    [:sensor_id, :start, :span].each { |p|
      unless params[p]
        halt 400, TEXT_PLAIN, "Parameter #{p.to_s} is needed."
      end
    }

    span_def = {
      "5-minutely" => { span: 300, interval: 3 },
      "hourly" => { span: 3600, interval: 30 },
      "daily" => { span: (24 * 3600), interval: 600 },
      "weekly" => { span: (7 * 24 * 3600), interval: 3600 },
      "monthly" => { span: (31 * 24 * 3600), interval: (6 * 3600) },
      "yearly" => { span: (366 * 24 * 3600), interval: (24 * 3600) }
    }

    sensor_id = params[:sensor_id].to_i
    start_time = Time.parse(params[:start])

    m = DeviceProperty.find(sensor_id).definitions("magnification").to_s
    return_hash = {}

    case params[:span]
    when "5-minutely"
      if start_time < (Time.now - (2 * 24 * 3600))
        halt 400, TEXT_PLAIN, "5-minutely, more than 2 days ago is invalid."
      end

      objs = SensorData.where( {
        :device_property_id => sensor_id,
        :measured_at => start_time .. (start_time + 301)
      } )

      objs.each { |obj|
        return_hash[obj.measured_at.strftime("%Y-%m-%d %H:%M:%S")] =
          m ? (BigDecimal(obj.value) * BigDecimal(m)).to_f.to_s : obj.value
      }
    when "hourly"
      if start_time < (Time.now - (2 * 24 * 3600))
        halt 400, TEXT_PLAIN, "hourly, more than 2 days ago is invalid."
      end

      t = start_time

      while t <= start_time + span_def["hourly"][:span]
        objs = SensorData.where( {
          :device_property_id => sensor_id,
          :measured_at => (t - 1) .. (t + 2)
        } )

        if objs.length > 0
          return_hash[objs[0].measured_at.strftime("%Y-%m-%d %H:%M:%S")] =
            m ? (BigDecimal(objs[0].value) * BigDecimal(m)).to_f.to_s : objs[0].value
        end

        t += span_def["hourly"][:interval]
      end
    when "daily"
      if start_time < (Time.now - (2 * 24 * 3600))
        objs = SensorHourlyData.where( {
          :device_property_id => sensor_id,
          :measured_at => start_time .. (start_time + span_def["daily"][:span] + 1)
        } )

        objs.each { |obj|
          return_hash[obj.measured_at.strftime("%Y-%m-%d %H:%M:%S")] =
            m ? (BigDecimal(obj.value) * BigDecimal(m)).to_f.to_s : obj.value
        }
      else
        t = start_time

        while t <= start_time + span_def["daily"][:span]
          objs = SensorData.where( {
            :device_property_id => sensor_id,
            :measured_at => (t - 1) .. (t + 10)
          } )

          if objs.length > 0
            return_hash[objs[0].measured_at.strftime("%Y-%m-%d %H:%M:%S")] =
              m ? (BigDecimal(objs[0].value) * BigDecimal(m)).to_f.to_s : objs[0].value
          end

          t += span_def["daily"][:interval]
        end
      end
    when "weekly", "monthly", "yearly"
      t = start_time

      while t <= start_time + span_def[params[:span]][:span]
        objs = SensorHourlyData.where( {
          :device_property_id => sensor_id,
          :measured_at => (t - 1800) .. (t + 1800)
        } )

        if objs.length > 0
          return_hash[objs[0].measured_at.strftime("%Y-%m-%d %H:%M:%S")] =
            m ? (BigDecimal(objs[0].value) * BigDecimal(m)).to_f.to_s : objs[0].value
        end

        t += span_def[params[:span]][:interval]
      end
    else
      halt 400, TEXT_PLAIN, "Parameter span is invalid."
    end

    JSON::generate(return_hash)
  end

  get '/api/sensor_alert', :provides => [:json] do
    [:sensor_id, :datetime].each { |p|
      unless params[p]
        halt 400, TEXT_PLAIN, "Parameter #{p.to_s} is needed."
      end
    }

    sensor_id = params[:sensor_id].to_i
    datetime = params[:datetime] ? params[:datetime] : Time.now

    objs = SensorAlert.where( {
      :device_property_id => sensor_id,
      :measured_at => (datetime - 60) .. (datetime + 1)
    } )

    if objs.length > 0
      objs.order("measured_at DESC")
      h = {
        "alert" => "1",
        "value" => magnify(sensor_id, objs[0].value),
        "min" => magnify(sensor_id, objs[0].monitor_min_value),
        "max" => magnify(sensor_id, objs[0].monitor_max_value)
      }
    else
      h = {}
    end

    JSON::generate(h)
  end

  get '/api/operation', :provides => [:json] do
    unless params[:gateway_id]
      halt 400, TEXT_PLAIN, "Parameter gateway_id is needed."
    end

    gateway_id = params[:gateway_id].to_i
    dps = DeviceProperty.where(gateway_id: gateway_id, sensor: false).select(:id)

    h = {}
    dps.each { |dp|
      op = Operation.pop(dp.id)
      if op
        h[op.device_property_id.to_s] = {
          "operation_id" => op.id.to_s,
          "value" => op.value
        }
        break
      end
    }

    JSON::generate(h)
  end

  get '/api/operation_status', :provides => [:json] do
    unless params[:operation_id]
      halt 400, TEXT_PLAIN, "Parameter operation_id is needed."
    end

    operation_id = params[:operation_id].to_i

    op = Operation.find(operation_id)
    if op
      h = {
        "value" => op.value,
        "status" => op.status == nil ? "" : op.status
      }
    else
      h = {}
    end

    JSON::generate(h)
  end

  private
  def sensor_data(posted_hash)
    id = posted_hash.keys[0]

    obj = SensorData.new(
      device_property_id: id.to_i,
      value: minify(id.to_i, posted_hash[id]),
      measured_at: Time.now
    )

    unless obj.save
      halt 500, TEXT_PLAIN, "Failed to save sensor data."
    end

    "OK"
  end

  def operation(posted_hash)
    id = posted_hash.keys[0]

    obj = Operation.new(
      device_property_id: id.to_i,
      value: posted_hash[id],
    )

    unless obj.push
      halt 500, TEXT_PLAIN, "Failed to save operation."
    end

    "{\"operation_id\":\"#{obj.id.to_s}\"}"
  end

  def operation_status(posted_hash)
    id = posted_hash.keys[0]

    obj = Operation.find(id.to_i)
    obj.status = posted_hash[id]

    unless obj.save
      halt 500, TEXT_PLAIN, "Failed to update operation status."
    end

    "OK"
  end

  def device(posted_hash)
    posted_hash = posted_hash.symbolize_keys
    key_array = [:hardware_uid, :class_group_code, :class_code, :properties]

    key_array.each { |k|
      unless posted_hash.has_key?(k)
        halt 400, TEXT_PLAIN, "'#{k.to_s}' is not found."
      end
    }

    # propertiesを変数に代入して、ハッシュから削除
    properties = posted_hash.delete(:properties)

    # gateway_idは暫定
    gateway_id = 1
    if Device.where(hardware_uid: posted_hash[:hardware_uid]).exists?
      device = Device.where(hardware_uid: posted_hash[:hardware_uid])[0]
    else
      device = Device.new({ gateway_id: gateway_id }.merge(posted_hash))
    end

    unless device.save
      halt 500, TEXT_PLAIN, "Failed to update device."
    end

    h = {}

    properties.keys.each { |k|
      property = DeviceProperty.new(
        gateway_id: gateway_id,
        device_id: device.id,
        class_group_code: posted_hash[:class_group_code],
        class_code: posted_hash[:class_code],
        property_code: k.to_s,
        sensor: properties[k] == "sensor"
      )

      unless property.save
        halt 500, TEXT_PLAIN, "Failed to save property '#{k.to_s}'."
      end

      h.store(k.to_s, property.id.to_s)
    }

    JSON::generate({device.id.to_s => h})
  end

  def device_property(posted_hash)
    id = posted_hash.keys[0]
    attributes = posted_hash[id].symbolize_keys

    obj = DeviceProperty.find(id.to_i)
    unless obj.update_attributes(attributes)
      halt 500, TEXT_PLAIN, "Cannot update."
    end
    sensor.save

    "OK"
  end

  def monitor(posted_hash)
    id = posted_hash.keys[0]
    attributes = {
      min_value: minify(id.to_i, posted_hash[id]["min"]),
      max_value: minify(id.to_i, posted_hash[id]["max"])
    }

    # sensor_idで検索
    # 見つかったら更新、無ければ追加
    objs = MonitorRange.where(device_property_id: id.to_i)

    if objs.length > 0
      obj = objs[0]
      obj.update_attributes(attributes)
    else
      obj = MonitorRange.new({ device_property_id: id.to_i }.merge(attributes))
    end

    unless obj.save
      halt 500, TEXT_PLAIN, "Failed to save monitor."
    end

    "OK"
  end

  def minify(device_property_id, value)
    m = DeviceProperty.find(device_property_id).definitions("magnification").to_s
    m ? (BigDecimal(value) / BigDecimal(m)).to_i.to_s : value
  end

  def magnify(device_property_id, value)
    m = DeviceProperty.find(device_property_id).definitions("magnification").to_s
    m ? (BigDecimal(value) * BigDecimal(m)).to_f.to_s : value
  end
end
