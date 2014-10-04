class User < ActiveRecord::Base
  attr_readonly :password_hash

  def password(p)
    self.password_hash = Digest::SHA256.hexdigest(s)
  end
end

class Gateway < ActiveRecord::Base
end

class UserGatewayRelation < ActiveRecord::Base
end

class Device < ActiveRecord::Base
end

class DeviceProperty < ActiveRecord::Base
end

class SensorData < ActiveRecord::Base
end

class ControllData < ActiveRecord::Base
end

class MonitorRange < ActiveRecord::Base
end

#class OpenData < ActiveRecord::Base
#end
