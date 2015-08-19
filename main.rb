require 'sinatra/base'
require 'sinatra/contrib'
require 'active_record'
require 'sqlite3'
require 'mysql2'
require 'json'
require 'sinatra/json'
require 'haml'
require 'digest'
require 'bigdecimal'

require 'sinatra/reloader'

require_relative './models'

ActiveRecord::Base.configurations = YAML.load_file('db/database.yml')
ActiveRecord::Base.establish_connection(Sinatra::Base.settings.environment)
ActiveRecord::Base.default_timezone = :local

Adapter = ActiveRecord::Base.connection.instance_values['config'][:adapter]

Time.zone = "Tokyo"

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

  get '/chart' do
    #unless session[:user_id]
    #  redirect '/login'
    #end

    haml :chart
  end

  get '/signup' do
    haml :signup
  end

  post '/signup' do
    logout

    user = User.new(
      login_name: params[:username],
      email: params[:email],
      nickname: params[:nickname]
    )

    user.password = params[:password]

    unless user.save
      halt 500, TEXT_PLAIN, "ユーザー登録に失敗しました。"
    end

    redirect "/login"
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

    if login({"username" => params[:username],
      "password_hash" => params[:password_hash]})
      redirect "/mypage"
    else
      redirect "/login"
    end
  end

  get '/mypage' do
    unless session[:user_id]
      redirect '/login'
    end

    @user = User.find(session[:user_id])

    if @user.nickname == nil || @user.nickname == ""
      @nickname = @user.login_name
    else
      @nickname = @user.nickname
    end

    haml :mypage
  end

  get '/logout' do
    logout
    redirect '/login'
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

    mob_api = [ "user", "gateway_add", "gateway_del",
      "sensor", "controller", "operation" ]

    if mob_api.include?(params[:type])
      unless session[:user_id]
        halt 403, TEXT_PLAIN, "Not logged in."
      end
    end

    return_value = case params[:type]
    when "login"
      login(posted_hash) ? "OK" : "NG"
    when "user"
      user_update(posted_hash)
    when "password"
      user_password(posted_hash)
    when "gateway_add"
      gateway_add(posted_hash)
    when "gateway_del"
      gateway_del(posted_hash)
    when "sensor_data"
      sensor_data(posted_hash)
    when "sensor_alert"
      sensor_alert(posted_hash)
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

    objs = DeviceProperty.lwhere(gateway_id: gateway_id, sensor: true)
    return_hash = {}

    objs.each { |obj|
      maxid = SensorData.where(device_property_id: obj.id).maximum(:id)
      d = maxid ? SensorData.find(maxid) : nil

      if d
        v = magnify(obj.id, d.value)
        dt = d.measured_at.strftime("%Y-%m-%d %H:%M:%S")
        a = if SensorAlert.where("device_property_id = ? AND measured_at >= ?",
          obj.id, d.measured_at - 30).exists?
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
          "unit" => obj.definitions("unit"),
          "datetime" => dt,
          "alert" => a
        }
      }

      return_hash = return_hash.merge(h)
    }

    JSON::generate(return_hash)
  end

  get '/api/controller', :provides => [:json] do
    if params[:gateway_id]
      gateway_id = params[:gateway_id]
    else
      halt 400, TEXT_PLAIN, "Parameter gateway_id is needed."
    end

    objs = DeviceProperty.lwhere(gateway_id: gateway_id, sensor: false)
    return_hash = {}

    objs.each { |obj|
      maxid = Operation.where(device_property_id: obj.id, status: "0").maximum(:id)
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

    sid = params[:sensor_id]
    start_time = Time.parse(params[:start])

    objs = DeviceProperty.lwhere(id: sid, sensor: true)
    if objs.empty?
      halt 400, TEXT_PLAIN, "Requested sensor_id not found."
    end

    span_def = {
      "5-minutely" => { span: 300, interval: 10 },
      "hourly" => { span: 3600, interval: 120 },
      "daily" => { span: (24 * 3600), interval: 3600 },
      "weekly" => { span: (7 * 24 * 3600), interval: 6 * 3600 },
      "monthly" => { span: (31 * 24 * 3600), interval: (24 * 3600) },
      "yearly" => { span: (366 * 24 * 3600), interval: (10 * 24 * 3600) }
    }

    m = DeviceProperty.find(sid.to_i).definitions("magnification").to_s
    m = m == "" ? "1" : m
    return_hash = {}

    case params[:span]
    when "5-minutely", "hourly"
      if start_time < (Time.now - (2 * 24 * 3600))
        halt 400, TEXT_PLAIN, "hourly, more than 2 days ago is invalid."
      end

      t = start_time

      while t <= start_time + span_def[params[:span]][:span]
        w = "device_property_id = #{sid}"
        w += " AND measured_at"
        w += " BETWEEN '#{(t - 1).strftime("%Y-%m-%d %H:%M:%S")}'"
        w += " AND '#{(t + span_def[params[:span]][:interval] - 1).strftime("%Y-%m-%d %H:%M:%S")}'"

        objs = SensorData.where(w)

        unless objs.empty?
          vals = []
          objs.each { |obj|
            vals << BigDecimal(obj.value)
          }

          avg = (vals.inject(:+) / vals.size).round

          return_hash[t.strftime("%Y-%m-%d %H:%M:%S")] =
            m ? (BigDecimal(avg) * BigDecimal(m)).to_f.to_s : objs[0].value
        end

        t += span_def[params[:span]][:interval]
      end
    when "daily"
      w = "device_property_id = #{sid}"
      w += " AND measured_at"
      w += " BETWEEN '#{start_time.strftime("%Y-%m-%d %H:%M:%S")}'"
      w += " AND '#{(start_time + span_def["daily"][:span] + 1).strftime("%Y-%m-%d %H:%M:%S")}'"

      objs = SensorHourlyData.where(w)

      objs.each { |obj|
        return_hash[obj.measured_at.strftime("%Y-%m-%d %H:%M:%S")] =
          m ? (BigDecimal(obj.value) * BigDecimal(m)).to_f.to_s : obj.value
      }

      shd_max = SensorHourlyData.where(device_property_id: sid.to_i).maximum(:measured_at)
      shd_max = shd_max == nil ? start_time : shd_max
      shd_max = shd_max < start_time ? start_time : shd_max

      if start_time + span_def["daily"][:span] > shd_max
        w = "device_property_id = #{sid}"
        w += " AND measured_at "
        w += " BETWEEN '#{shd_max.strftime("%Y-%m-%d %H:%M:%S")}'"
        w += " AND '#{(start_time + span_def["daily"][:span]).strftime("%Y-%m-%d %H:%M:%S")}'"

        date_format = case Adapter
        when "mysql2"
          "DATE_FORMAT(measured_at, '%Y-%m-%d %H:00:00') AS at"
        when "sqlite3"
          "strftime(measured_at, '%Y-%m-%d %H:00:00') AS at"
        else
          "TO_CHAR(measured_at, 'YYYY-MM-DD HH24:00:00') AS at"
        end

        objs = SensorData.where(w).select(date_format).uniq

        objs.each { |obj|
          if obj.at == nil || t > (start_time + span_def["daily"][:span])
            break
          end

          t = Time.parse(obj.at)

          w = "device_property_id = #{sid}"
          w += " AND measured_at"
          w += " BETWEEN '#{t.strftime("%Y-%m-%d %H:%M:%S")}'"
          w += " AND '#{(t + span_def["daily"][:interval]).strftime("%Y-%m-%d %H:%M:%S")}'"
          datas = SensorData.where(w)

          vals = []
          datas.each { |d|
            vals << BigDecimal(d.value)
          }
          vals.sort!

          v = if vals.size >= 100
            vals[2..-3].inject(:+) / vals[2..-3].size
          else
            vals.inject(:+) / vals.size
          end
          v = v.round

          return_hash[obj.at] =
            m ? (BigDecimal(v) * BigDecimal(m)).to_f.to_s : v
        }
      end
    when "weekly", "monthly", "yearly"
      t = start_time
      shd_max = SensorHourlyData.where(device_property_id: sid.to_i).maximum(:measured_at)
      shd_max = shd_max == nil ? start_time : shd_max

      while t <= start_time + span_def[params[:span]][:span]
        if t > shd_max
          break
        end

        w = "device_property_id = #{sid}"
        w += " AND measured_at"
        w += " BETWEEN '#{(t - 1800).strftime("%Y-%m-%d %H:%M:%S")}'"
        w += " AND '#{(t + 1800).strftime("%Y-%m-%d %H:%M:%S")}'"

        objs = SensorHourlyData.where(w)

        unless objs.empty?
          return_hash[objs[0].measured_at.strftime("%Y-%m-%d %H:%M:%S")] =
            m ? (BigDecimal(objs[0].value) * BigDecimal(m)).to_f.to_s : objs[0].value
        end

        if params[:span] == "yearly"
          t = case t.day
          when 20 && t.mon == 2
              Time.new(t.year, 3, 1, t.hour, 0, 0)
          when 21..31
            Time.new(t.year, t.mon + 1, t.day - 20, t.hour, 0, 0)
          else
            t + 10 * 24 * 3600
          end
        else
          t += span_def[params[:span]][:interval]
        end
      end

      if start_time + span_def[params[:span]][:span] > shd_max
        w = "device_property_id = #{sid}"
        w += " AND measured_at "
        w += " BETWEEN '#{shd_max.strftime("%Y-%m-%d %H:%M:%S")}'"
        w += " AND '#{(start_time + span_def[params[:span]][:span]).strftime("%Y-%m-%d %H:%M:%S")}'"

        date_format = case Adapter
        when "mysql2"
          "DATE_FORMAT(measured_at, '%Y-%m-%d %H:00:00') AS at"
        when "sqlite3"
          "strftime(measured_at, '%Y-%m-%d %H:00:00') AS at"
        else
          "TO_CHAR(measured_at, 'YYYY-MM-DD HH24:00:00') AS at"
        end

        objs = SensorData.where(w).select(date_format).uniq

        objs.each { |obj|
          if obj.at == nil
            break
          end

          if t == Time.parse(obj.at)
            w = "device_property_id = #{sid}"
            w += " AND measured_at"
            w += " BETWEEN '#{t.strftime("%Y-%m-%d %H:%M:%S")}'"
            w += " AND '#{(t + 3600).strftime("%Y-%m-%d %H:%M:%S")}'"
            datas = SensorData.where(w)

            vals = []
            datas.each { |d|
              vals << BigDecimal(d.value)
            }
            vals.sort!

            v = if vals.size >= 100
              vals[2..-3].inject(:+) / vals[2..-3].size
            else
              vals.inject(:+) / vals.size
            end
            v = v.round

            return_hash[obj.at] =
              m ? (BigDecimal(v) * BigDecimal(m)).to_f.to_s : v
          end

          t += span_def[params[:span]][:interval]
        }
      end
    else
      halt 400, TEXT_PLAIN, "Parameter span is invalid."
    end

    JSON::generate(return_hash)
  end

  get '/api/sensor_alert', :provides => [:json] do
    unless params[:sensor_id]
      halt 400, TEXT_PLAIN, "Parameter sensor_id is needed."
    end

    sensor_id = params[:sensor_id].to_i

    unless DeviceProperty.lexists?( id: sensor_id, sensor: true )
      halt 400, TEXT_PLAIN, "Requested sensor_id not found"
    end

    datetime = params[:datetime] ? Time.parse(params[:datetime]) : Time.now

    w = "device_property_id = #{params[:sensor_id]}"
    w += " AND measured_at"
    w += " BETWEEN '#{(datetime - 60).strftime("%Y-%m-%d %H:%M:%S")}'"
    w += " AND '#{(datetime + 1).strftime("%Y-%m-%d %H:%M:%S")}'"
    objs = SensorAlert.where(w).order("measured_at DESC")

    if objs.empty?
      h = {}
    else
      h = {
        "alert" => "1",
        "value" => magnify(sensor_id, objs[0].value),
        "min" => magnify(sensor_id, objs[0].monitor_min_value),
        "max" => magnify(sensor_id, objs[0].monitor_max_value)
      }
    end

    JSON::generate(h)
  end

  get '/api/operation', :provides => [:json] do
    unless params[:gateway_id]
      halt 400, TEXT_PLAIN, "Parameter gateway_id is needed."
    end

    gateway_id = params[:gateway_id].to_i
    dps = DeviceProperty.lwhere(gateway_id: gateway_id, sensor: false).select(:id)

    h = {}

    unless dps.empty?
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
    end

    JSON::generate(h)
  end

  get '/api/operation_status', :provides => [:json] do
    unless params[:operation_id]
      halt 400, TEXT_PLAIN, "Parameter operation_id is needed."
    end

    operation_id = params[:operation_id].to_i

    h = if Operation.exists?(id: operation_id)
      op = Operation.find(operation_id)

      {
        "value" => op.value,
        "status" => op.status == nil ? "" : op.status
      }
    else
      {}
    end

    JSON::generate(h)
  end

  get '/api/sensor_data_sum', :provides => [:text] do
    stream do |out|
      s = "measured_at < "
      s += "'#{(Time.now - 49 * 60 * 60).strftime("%Y-%m-%d %H:%M:%S")}'"

      oldest_ts = SensorData.minimum(:measured_at)
      if oldest_ts < (Time.now - 6 * 24 * 60 * 60)
        s = "measured_at < "
        s += "'#{(oldest_ts + 3 * 24 * 60 * 60).strftime("%Y-%m-%d %H:%M:%S")}'"
      end

      while SensorData.where(s).exists?
        oldest = SensorData.where(s)
        oldest = oldest.group(:device_property_id).minimum(:measured_at)

        oldest.each { |k, v|
          t = Time.new(v.year, v.mon, v.day, v.hour)

          w = "device_property_id = #{k.to_s}"
          w += " AND measured_at"
          w += " BETWEEN '#{t.strftime("%Y-%m-%d %H:%M:%S")}'"
          w += " AND '#{(t + 3600).strftime("%Y-%m-%d %H:%M:%S")}'"
          datas = SensorData.where(w)

          unless SensorHourlyData.exists?(measured_at: t)
            vals = []
            datas.each { |d|
              vals << BigDecimal(d.value)
            }
            vals.sort!

            if vals.size >= 100
              min = vals[2]
              max = vals[-3]
              avg = vals[2..-3].inject(:+) / vals[2..-3].size
            else
              min = vals[0]
              max = vals[-1]
              avg = vals.inject(:+) / vals.size
            end

            shd = SensorHourlyData.new( {
              device_property_id: k,
              value: avg.to_i.to_s,
              min_3rd_value: min.to_i.to_s,
              max_3rd_value: max.to_i.to_s,
              measured_at: t
              } )

            unless shd.save
              halt 500, TEXT_PLAIN, "Failed to save sensor hourly data."
            end

            out << "#{k.to_s} | #{t.strftime("%Y-%m-%d %H:%M:%S")}\n"
          end

          datas.destroy_all(w)
        }
      end
    end
  end

  private
  def login(posted_hash)
    if user = User.where(:login_name => posted_hash["username"]).first
      if user.password_hash == posted_hash["password_hash"]
        session[:user_id] = user.id
        true
      else
        false
      end
    else
      false
    end
  end

  def logout
    session[:user_id] = nil
  end

  def user_update(posted_hash)
    user = User.find(session[:user_id])

    user.nickname = posted_hash["nickname"]
    user.email = posted_hash["email"]

    unless user.save
      halt 500, TEXT_PLAIN, "Failed to save the user information."
    end
  end

  def user_password(posted_hash)
    user = User.find(session[:user_id])
    user.password = posted_hash["password"]
    unless user.save
      halt 500, TEXT_PLAIN, "Failed to change your password."
    end
  end

  def gateway_add(posted_hash)
    if Gateway.exists?(hardware_uid: posted_hash["hardware_uid"])
      gw = Gateway.where(hardware_uid: posted_hash["hardware_uid"]).first
    else
      gw = Gateway.new(
        hardware_uid: posted_hash["hardware_uid"],
        name: posted_hash["name"]
      )

      unless gw.save
        halt 500, TEXT_PLAIN, "Failed to save this gateway."
      end
    end

    unless UserGatewayRelation.exists?(
      user_id: session[:user_id],
      gateway_id: gw.id)

      r = UserGatewayRelation.new(
        user_id: session[:user_id],
        gateway_id: gw.id)

      unless r.save
        halt 500, TEXT_PLAIN, "Failed to save this gateway."
      end
    end

    "OK"
  end

  def gateway_del(posted_hash)
    gw = Gateway.where(hardware_uid: posted_hash["hardware_uid"]).first

    UserGatewayRelation.destroy_all(
      user_id: session[:user_id],
      gateway_id: gw.id)
  end

  def sensor_data(posted_hash)
    id = posted_hash.keys[0]

    unless DeviceProperty.lexists?(id: id.to_i, sensor: true)
      halt 400, TEXT_PLAIN, "Posted sensor_id not found."
    end

    val = minify(id.to_i, posted_hash[id])
    ts = Time.now

    obj = SensorData.new(
      device_property_id: id.to_i,
      value: val,
      measured_at: ts
    )

    unless obj.save
      halt 500, TEXT_PLAIN, "Failed to save sensor data."
    end

    "OK"
  end

  def sensor_alert(posted_hash)
    id = posted_hash.keys[0]

    unless DeviceProperty.lexists?(id: id.to_i, sensor: true)
      halt 400, TEXT_PLAIN, "Posted sensor_id not found."
    end

    vals = []
    [ "value", "min", "max" ].each { |k|
      if posted_hash[id][k] == nil
        halt 400, TEXT_PLAIN, "Posted #{k} not found."
      else
        vals << minify(id.to_i, posted_hash[id][k])
      end
    }

    alrt = SensorAlert.new(
      device_property_id: id.to_i,
      value: vals[0],
      monitor_min_value: vals[1],
      monitor_max_value: vals[2],
      measured_at: Time.now
    )

    unless alrt.save
      halt 500, TEXT_PLAIN, "Failed to save sensor alert."
    end

    "OK"
  end

  def operation(posted_hash)
    id = posted_hash.keys[0]

    unless DeviceProperty.lexists?( id: id.to_i, sensor: false )
      halt 400, TEXT_PLAIN, "Posted controller_id not found."
    end

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

    # Gatewayが"2"を返しているとのことで暫定対応
    if obj.status == "2"
      obj.status = "0"
    end

    unless obj.save
      halt 500, TEXT_PLAIN, "Failed to update operation status."
    end

    "OK"
  end

  def device(posted_hash)
    posted_hash = posted_hash.symbolize_keys

    [:hardware_uid, :class_group_code, :class_code, :properties].each { |k|
      unless posted_hash.has_key?(k)
        halt 400, TEXT_PLAIN, "'#{k.to_s}' is not found."
      end
    }

    # propertiesを変数に代入して、ハッシュから削除
    pties = posted_hash.delete(:properties)

    # gateway_idは暫定
    gateway_id = 1
    if Device.where(hardware_uid: posted_hash[:hardware_uid]).exists?
      device = Device.where(hardware_uid: posted_hash[:hardware_uid])[0]
    else
      device = Device.new({ gateway_id: gateway_id }.merge(posted_hash))
    end

    ary = []
    p_ary = []
    ids = []

    pties.each { |h|
      h = h.symbolize_keys

      [:class_group_code, :class_code, :property_code, :type].each { |k|
        unless h.has_key?(k)
          halt 400, TEXT_PLAIN, "'properties'.'#{k.to_s}' is not found."
        end
      }

      properties = DeviceProperty.where(
        device_id: device.id,
        class_group_code: h[:class_group_code],
        class_code: h[:class_code],
        property_code: h[:property_code]
      )

      if properties.empty?
        property = DeviceProperty.new(
          gateway_id: gateway_id,
          device_id: device.id,
          class_group_code: h[:class_group_code],
          class_code: h[:class_code],
          property_code: h[:property_code],
          sensor: h[:type] == "sensor"
        )
      else
        property = properties[0]
        property.lrestore
      end

      ary << {
        "id" => property.id.to_s,
        "class_group_code" => h[:class_group_code],
        "class_code" => h[:class_code],
        "property_code" => h[:property_code]
      }
      p_ary << property
      ids << property.id
    }

    unless device.save
      halt 500, TEXT_PLAIN, "Failed to update device."
    end

    p_ary.each { |property|
      unless property.save
        halt 500, TEXT_PLAIN, "Failed to save property '#{property.id.to_s}'."
      end
    }

    objs = DeviceProperty.where(device_id: device.id)
    objs.where.not(id: ids)
    objs.each { |obj|
      obj.ldelete
      obj.save
    }

    JSON::generate({device.id.to_s => ary})
  end

  def device_property(posted_hash)
    id = posted_hash.keys[0]
    attributes = posted_hash[id].symbolize_keys

    obj = DeviceProperty.find(id.to_i)
    unless obj.update_attributes(attributes)
      halt 500, TEXT_PLAIN, "Cannot update."
    end
    obj.save

    "OK"
  end

  def monitor(posted_hash)
    id = posted_hash.keys[0]

    unless DeviceProperty.lexists?( id: id.to_i, sensor: true )
      halt 400, TEXT_PLAIN, "Posted sensor_id not found."
    end

    attributes = {
      min_value: minify(id.to_i, posted_hash[id]["min"]),
      max_value: minify(id.to_i, posted_hash[id]["max"])
    }

    # sensor_idで検索
    # 見つかったら更新、無ければ追加
    objs = MonitorRange.where(device_property_id: id.to_i)

    if objs.empty?
      obj = MonitorRange.new({ device_property_id: id.to_i }.merge(attributes))
    else
      obj = objs[0]
      obj.update_attributes(attributes)
    end

    unless obj.save
      halt 500, TEXT_PLAIN, "Failed to save monitor."
    end

    "OK"
  end

  def minify(device_property_id, value)
    m = DeviceProperty.find(device_property_id).definitions("magnification").to_s
    m != "" ? (BigDecimal(value) / BigDecimal(m)).to_i.to_s : value
  end

  def magnify(device_property_id, value)
    m = DeviceProperty.find(device_property_id).definitions("magnification").to_s
    m != "" ? (BigDecimal(value) * BigDecimal(m)).to_f.to_s : value
  end
end
