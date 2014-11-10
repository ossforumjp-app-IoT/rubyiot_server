require 'active_record'
require 'json'
require_relative './models'

SensorID = 1
START = Time.now - 5 * 24 * 60 * 60
INTERVAL = 3
SPAN = 5 * 24 * 60 * 60 / INTERVAL

rails_env = ENV["RAILS_ENV"] ? ENV["RAILS_ENV"].to_sym : :development

ActiveRecord::Base.configurations = YAML.load_file('db/database.yml')
ActiveRecord::Base.establish_connection(rails_env)
ActiveRecord::Base.default_timezone = :local

Time.zone = "Tokyo"

r = Random.new(Random.new_seed)
t = START

newest_sd = SensorData.where(device_property_id: SensorID).order(:measured_at).last

v = if newest_sd == nil
  case t.mon
  when 12, 1, 2; 16
  when 3, 4, 10, 11; 18
  when 5, 6, 9; 20
  when 7, 8; 24
  end
else
  newest_sd.value.to_f * 0.1
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
      v -= 0.1
    elsif v < 20
      v += 0.1
    end
  when 7, 8
    if v > 33
      v -= 0.1
    elsif v < 25
      v += 0.1
    end
  end

  SensorData.create(
    device_property_id: SensorID,
    value: (v * 10).round.to_s,
    measured_at: t
  )

  w = "device_property_id = #{SensorID.to_s}"
  w += " AND updated_at < #{t.strftime("%Y-%m-%d %H:%M:%S")}"

  if MonitorRange.exists?(w)
    mons = MonitorRange.where(w)

    min = BigDecimal(mons[0].min_value)
    max = BigDecimal(mons[0].max_value)
    val = BigDecimal(v * 10)

    if val <= min || val >= max
      alrt = SensorAlert.create(
        device_property_id: id.to_i,
        value: val.round.to_s,
        monitor_min_value: mons[0].min_value,
        monitor_max_value: mons[0].max_value,
        measured_at: t
      )
    end
  end
}
