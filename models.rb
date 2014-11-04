module Echonet
  Defs = JSON::parse(open("public/echonet-device-objects.json").read)

  module ClassGroup
    def class_group_name
      unless self.class_group_code
        return nil
      end

      if Defs[self.class_group_code].class == Hash
        return Defs[self.class_group_code]["class_group_name"]
      else
        return nil
      end
    end
  end

  module Class
    def class_name
      unless self.class_group_code
        return nil
      end

      unless self.class_code
        return nil
      end

      unless Defs[self.class_group_code] == Hash
        return nil
      end

      unless Defs[self.class_group_code][self.class_code] == Hash
        return nil
      end

      Defs[self.class_group_code][self.class_code]["class_name"]
    end
  end

  module Property
    def definitions(def_name)
      unless self.class_group_code
        return nil
      end

      unless self.class_code
        return nil
      end

      unless self.property_code
        return nil
      end

      unless Defs[self.class_group_code] == Hash
        return nil
      end

      unless Defs[self.class_group_code][self.class_code] == Hash
        return nil
      end

      unless Defs[self.class_group_code][self.class_code][self.property_code] == Hash
        return nil
      end

      Defs[self.class_group_code][self.class_code][self.property_code][def_name]
    end

    def property_name
      self.definitions("property_name")
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
  self.table_name = 'sensor_datas'
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

  @@queue = {}

  def push
    if self.device_property_id
      dpid = self.device_property_id.to_s
    else
      return false
    end

    if self.value
      v = self.value
    else
      return false
    end

    unless @@queue.has_key?(dpid)
      @@queue[dpid] = []
    end

    if self.save
      @@queue[dpid].push( { id: self.id, value: v } )
      return true
    else
      return false
    end
  end

  def self.pop(device_property_id)
    if @@queue[device_property_id.to_s].length > 0
      op = @@queue[device_property_id.to_s].shift
      obj = self.find(op[:id])
      obj.status = ""
      obj.save
      obj
    else
      nil
    end
  end
end
