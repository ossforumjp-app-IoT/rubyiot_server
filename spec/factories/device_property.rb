FactoryGirl.define do
  factory :sensor_dp, class: DeviceProperty do
    sequence(:name) { |n| "sensor_dp_#{n}" }
    sensor true
  end

  factory :not_sensor_dp, class: DeviceProperty do
    sequence(:name) { |n| "not_sensor_dp_#{n}" }
    sensor false
  end
end
