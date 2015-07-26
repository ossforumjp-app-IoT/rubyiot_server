require File.dirname(__FILE__) + "/spec_helper"

RSpec.shared_examples "return_status_code" do |param|
  it "ステータスコードが#{param}であること" do
    expect(last_response.status).to eq(param)
  end
end

RSpec.shared_examples "return_body_message" do |param|
  it "メッセージが#{param}であること" do
    expect(last_response.body).to eq(param)
  end
end

RSpec.describe MainApp do
  include Rack::Test::Methods

  def app
    MainApp.new
  end

  describe "/へのアクセス" do
    before { get "/" }
    subject { last_response }

    include_examples "return_status_code", 200

    include_examples "return_body_message", "hello world!"
  end

  describe "/chartへのアクセス" do
    before { get "/chart" }
    subject { last_response }

    include_examples "return_status_code", 200

    it "BodyにhighchartのJavaScript読み込み処理があること" do
      expect(subject.body).to match /highcharts\.js/
    end
  end

  describe "/api/sensorへのアクセス" do
    posted_data = { "10" => { "name" => "name1" } }
    before do
      DeviceProperty.delete_all
      DeviceProperty.create(id: posted_data.keys[0].to_i)
      post "/api/sensor", posted_data.to_json
    end

    include_examples "return_status_code", 201
    include_examples "return_body_message", "OK"

    it "DevicePropertyのnameが設定されていること" do
      expect(DeviceProperty.find(posted_data.keys[0].to_i).name).to eq("name1")
    end
  end

  describe "/api/controllerへのアクセス" do
    posted_data = { "10" => { "name" => "name1" } }
    before do
      DeviceProperty.delete_all
      DeviceProperty.create(id: posted_data.keys[0].to_i)
      post "/api/sensor", posted_data.to_json
    end

    include_examples "return_status_code", 201
    include_examples "return_body_message", "OK"

    it "DevicePropertyのnameが設定されていること" do
      expect(DeviceProperty.find(posted_data.keys[0].to_i).name).to eq("name1")
    end
  end

  describe "/api/monitorへのアクセス" do
    posted_data = { "10" => { "min" => "12", "max" => "43" } }
    before do
      DeviceProperty.delete_all
      DeviceProperty.create(id: posted_data.keys[0].to_i, sensor: true)
      post "/api/monitor", posted_data.to_json
    end

    include_examples "return_status_code", 201
    include_examples "return_body_message", "OK"

    it "MonitorRangeのmax/minが設定されていること" do
      id = posted_data.keys[0].to_i
      expect(MonitorRange.where(device_property_id: id).first.min_value).to eq("12")
      expect(MonitorRange.where(device_property_id: id).first.max_value).to eq("43")
    end
  end
end
