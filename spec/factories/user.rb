FactoryGirl.define do
  factory :user do
    login_name     "test_user"
    email          "test_user@example.com"
    password_hash  "abc"   # TODO 本来はpasswordとpassword_confirmationを設定すべき
  end
end
