module Echonet
  Hash = JSON::parse(open("public/echonet-device-objects.json").read)

  module ClassGroup
    def class_group_name
      Hash[@class_group_code]["class_group_name"]
    end
  end

  module Class
    def class_name
      Hash[@class_group_code][@class_code]["class_name"]
    end
  end

  module Property
    def property_name
      Hash[@class_group_code][@class_code][@property_code]["property_name"]
    end

    def definitions
      Hash[@class_group_code][@class_code][@property_code]
    end
  end
end

class User < ActiveRecord::Base
  has_many :user_gateway_relations
  attr_readonly :password_hash

  def password(s)
    @password_hash = Digest::SHA256.hexdigest(s)
  end
end

class Gateway < ActiveRecord::Base
  has_many :user_gateway_relations
  has_many :devices
end

class UserGatewayRelation < ActiveRecord::Base
  belongs_to :user
  belongs_to :gateway
end

class Device < ActiveRecord::Base
  include Echonet::ClassGroup
  include Echonet::Class

  belongs_to :gateway
  has_many :device_properties
end

class DeviceProperty < ActiveRecord::Base
  include Echonet::ClassGroup
  include Echonet::Class
  include Echonet::Property

  belongs_to :device
  has_many :sensor_datas
  has_many :sensor_hourly_datas
  has_many :sensor_alerts
  has_many :monitor_ranges
  has_many :operations
end

class SensorData < ActiveRecord::Base
  belongs_to :device_property
end

class SensorHourlyData < ActiveRecord::Base
  belongs_to :device_property
end

class MonitorRange < ActiveRecord::Base
  belongs_to :device_property
end

class SensorAlert < ActiveRecord::Base
  belongs_to :device_property
end

class Operation < ActiveRecord::Base
  belongs_to :device_property

  @@queue = []

  def push
    @@queue.push( { "device_property_id" => @device_property_id, "value" => @value } )
  end

  def pop
    op = @@queue.shift
    @device_property_id = op["device_property_id"]
    @value = op["value"]
    self.save
    @id
  end
end
