FactoryGirl.define do
  factory :sensor_hourly_data do
    measured_at { Time.now }
  end
end
