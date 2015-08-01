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
    context "GET" do
      before do
        DeviceProperty.delete_all
        SensorData.delete_all

        @dp1 = DeviceProperty.create(gateway_id: 12, name: "dp1", sensor: true)
        @dp2 = DeviceProperty.create(gateway_id: 12, name: "dp2", sensor: true)
        SensorData.create(device_property_id: @dp1.id, measured_at: Time.now)
        SensorData.create(device_property_id: @dp2.id, measured_at: Time.now)

        get "/api/sensor", gateway_id: "12"
      end

      include_examples "return_status_code", 200

      it "返されるJSONにdp1の項目が設定されていること" do
        expect(last_response.body).to be_json_eql("\"#{@dp1.name}\"").at_path("#{@dp1.id}/name")
      end

      it "返されるJSONにdp2の項目が設定されていること" do
        expect(last_response.body).to be_json_eql("\"#{@dp2.name}\"").at_path("#{@dp2.id}/name")
      end
    end

    context "POST" do
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
  end

  describe "/api/sensor_dataへのアクセス" do
    context "GET" do
      before do
        DeviceProperty.delete_all
        dp = DeviceProperty.create(sensor: true)
        base_time = Time.now - 3*24*60*60 # 現在時刻の3日前

        @shd1 = SensorHourlyData.create(device_property_id: dp.id, measured_at: base_time + 60*60, value: "123")
        @shd2 = SensorHourlyData.create(device_property_id: dp.id, measured_at: base_time + 2*60*60, value: "456")
        @shd3 = SensorHourlyData.create(device_property_id: dp.id, measured_at: base_time + 3*60*60, value: "789")

        @sd1 = SensorData.create(device_property_id: dp.id, measured_at: base_time + 60*60)
        @sd2 = SensorData.create(device_property_id: dp.id, measured_at: base_time + 2*60*60)
        @sd3 = SensorData.create(device_property_id: dp.id, measured_at: base_time + 3*60*60)
        get "/api/sensor_data", sensor_id: dp.id, start: base_time.to_s, span: "daily"
      end

      include_examples "return_status_code", 200

      it "返されるJSONにが設定されていること" do
        expect(last_response.body).to be_json_eql(
          {@shd1.measured_at.strftime("%Y-%m-%d %H:%M:%S") => @shd1.value.to_f.to_s,
           @shd2.measured_at.strftime("%Y-%m-%d %H:%M:%S") => @shd2.value.to_f.to_s,
           @shd3.measured_at.strftime("%Y-%m-%d %H:%M:%S") => @shd3.value.to_f.to_s,
 }.to_json)
      end
    end

    context "POST" do
      posted_data = { "10" => "measured_data" }
      before do
        DeviceProperty.delete_all
        DeviceProperty.create(id: posted_data.keys[0].to_i, sensor: true)
        post "/api/sensor_data", posted_data.to_json
      end

      include_examples "return_status_code", 201
      include_examples "return_body_message", "OK"

      it "SensorDataのvalueが設定されていること" do
        id = posted_data.keys[0].to_i
        expect(SensorData.where(device_property_id: id).first.value).to eq("measured_data")
      end
    end
  end

  describe "/api/sensor_alertへのアクセス" do
    posted_data = { "10" => { "value" => "val1", "min": "min1", "max": "max1" } }
    before do
      DeviceProperty.delete_all
      DeviceProperty.create(id: posted_data.keys[0].to_i, sensor: true)
      post "/api/sensor_alert", posted_data.to_json
    end

    include_examples "return_status_code", 201
    include_examples "return_body_message", "OK"

    it "SensorAlertのvalue,monitor_min_value,monitor_max_valueが設定されていること" do
      sa = SensorAlert.where(device_property_id: posted_data.keys[0].to_i).first
      expect(sa.value).to eq("val1")
      expect(sa.monitor_min_value).to eq("min1")
      expect(sa.monitor_max_value).to eq("max1")
    end
  end

  describe "/api/operationへのアクセス" do
    posted_data = { "10" => "operation_value" }
    before do
      DeviceProperty.delete_all
      DeviceProperty.create(id: posted_data.keys[0].to_i, sensor: false)
      post "/api/operation", posted_data.to_json
    end

    include_examples "return_status_code", 201

    it "返却されるJSONにoperation_idがあること" do
      expect(last_response.body).to have_json_path("operation_id")
    end

    it "OperationのValueが設定されていること" do
      op = Operation.where(device_property_id: posted_data.keys[0].to_i).first
      expect(op.value).to eq("operation_value")
    end
  end

  describe "/api/operation_statusへのアクセス" do
    posted_data = { "10" => "0" }
    before do
      Operation.delete_all
      Operation.create(id: posted_data.keys[0].to_i)
      post "/api/operation_status", posted_data.to_json
    end

    include_examples "return_status_code", 201
    include_examples "return_body_message", "OK"

    it "Operationのstatusが設定されていること" do
      op = Operation.find(posted_data.keys[0].to_i)
      expect(op.status).to eq("0")
    end
  end

  describe "/api/deviceへのアクセス" do
    posted_data = { "hardware_uid" => "hardware_uid",
                    "properties" =>
                        [
                          { "class_group_code" => "0x01",
                            "class_code" => "0x02",
                            "property_code" => "0x03",
                            "type" => "sensor" },
                        ],
                    "class_group_code" => "dummy",
                    "class_code" => "dummy"
    }

    before do
      Device.delete_all
      DeviceProperty.delete_all
      post "/api/device", posted_data.to_json
    end

    include_examples "return_status_code", 201

    it "返却されるJSONにclass_group_code, class_code, property_codeがあること" do
      d = Device.all.order(:created_at).first
      expect(last_response.body).to have_json_path("#{d.id}/0/class_group_code")
      expect(last_response.body).to have_json_path("#{d.id}/0/class_code")
      expect(last_response.body).to have_json_path("#{d.id}/0/property_code")
    end

    it "Deviceのhardware_uidが設定されていること" do
      device = Device.where(gateway_id: 1).first
      expect(device.hardware_uid).to eq("hardware_uid")
    end
  end

  describe "/api/controllerへのアクセス" do
    context "GET" do
      before do
        DeviceProperty.delete_all
        Operation.delete_all

        @dp1 = DeviceProperty.create(gateway_id: 12, name: "dp1", sensor: false)
        @dp2 = DeviceProperty.create(gateway_id: 12, name: "dp2", sensor: false)
        Operation.create(device_property_id: @dp1.id, status: 0)
        Operation.create(device_property_id: @dp2.id, status: 0)

        get "/api/controller", gateway_id: "12"
      end

      include_examples "return_status_code", 200

      it "返されるJSONにdp1の項目が設定されていること" do
        expect(last_response.body).to be_json_eql("\"#{@dp1.name}\"").at_path("#{@dp1.id}/name")
      end

      it "返されるJSONにdp2の項目が設定されていること" do
        expect(last_response.body).to be_json_eql("\"#{@dp2.name}\"").at_path("#{@dp2.id}/name")
      end
    end

    context "POST" do
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
  end

  describe "/api/monitorへのアクセス" do
    context "GET" do
      before do
        MonitorRange.delete_all
        DeviceProperty.delete_all

        MonitorRange.create(device_property_id: 124, min_value: 101, max_value: 4321)
        DeviceProperty.create(id: 124)

        get "/api/monitor", sensor_id: 124
      end

      include_examples "return_status_code", 200

      it "返されるJSONにminの項目が設定されていること" do
        expect(last_response.body).to be_json_eql("\"101\"").at_path("min")
      end

      it "返されるJSONにmaxの項目が設定されていること" do
        expect(last_response.body).to be_json_eql("\"4321\"").at_path("max")
      end
    end

    context "POST" do
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
end
