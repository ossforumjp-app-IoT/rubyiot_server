FactoryGirl.define do
  factory :operation do
    value { ("1".."9").to_a.shuffle.join[0,3] }
  end
end
