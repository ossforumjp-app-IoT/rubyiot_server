FactoryGirl.define do
  factory :sensor_alert do
    measured_at { Time.now }
    value { ("1".."9").to_a.shuffle.join[0,3] }
  end
end
