require 'active_record'
require 'json'
require_relative './models'

SensorID = 1
START = Time.now - 365 * 24 * 60 * 60
INTERVAL = 3
SPAN = 5 * 24 * 60 * 60 / INTERVAL

rails_env = ENV["RAILS_ENV"] ? ENV["RAILS_ENV"].to_sym : :development

ActiveRecord::Base.configurations = YAML.load_file('db/database.yml')
ActiveRecord::Base.establish_connection(rails_env)
ActiveRecord::Base.default_timezone = :local

Time.zone = "Tokyo"

r = Random.new(Random.new_seed)
t = START
v = case t.mon
  when 12, 1, 2; 18
  when 3, 4, 10, 11; 21
  when 5, 6, 9; 24
  when 7, 8; 27
  end

(0..SPAN).each {
  adj = case t.hour
    when 15..23, 0..5
      -0.0003
    when 6..14
      0.0005
    end

  v += r.rand * 0.04 - 0.02 + adj
  t += INTERVAL

  case t.mon
  when 12, 1, 2
    if v > 20
      v -= 0.1
    elsif v < 12
      v += 0.1
    end
  when 3, 4, 10, 11
    if v > 25
      v -= 0.1
    elsif v < 15
      v += 0.1
    end
  when 5, 6, 9
    if v > 27
      v += 0.1
    elsif v < 20
      v += 0.1
    end
  when 7, 8
    if v > 33
      v += 0.1
    elsif v < 25
      v += 0.1
    end
  end

  SensorData.create({
    device_property_id: SensorID,
    value: (v * 10).round.to_s,
    measured_at: t
  })
}
