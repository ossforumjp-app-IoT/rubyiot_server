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
        send_gateway_id = 12   # 適当につけた値
        @dp1 = create(:sensor_dp, gateway_id: send_gateway_id)
        @dp2 = create(:sensor_dp, gateway_id: send_gateway_id)
        create(:sensor_data, device_property_id: @dp1.id)
        create(:sensor_data, device_property_id: @dp2.id)
        user = create(:user)

        get "/api/sensor", { gateway_id: send_gateway_id.to_s }, { "rack.session" => { user_id: user.id } }
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
        create(:sensor_dp, id: posted_data.keys[0].to_i)
        user = create(:user)

        post "/api/sensor", posted_data.to_json, { "rack.session" => { user_id: user.id } }
      end

      include_examples "return_status_code", 201
      include_examples "return_body_message", "OK"

      it "DevicePropertyのnameが設定されていること" do
        expect(DeviceProperty.find(posted_data.keys[0].to_i).name).to eq("name1")
      end
    end
  end

  describe "/api/sensor_dataへのアクセス" do
    describe "GET" do
      context "daily" do
        before do
          dp = create(:sensor_dp)
          base_time = Time.now - 3*24*60*60 # 現在時刻の3日前

          @shd1 = create(:sensor_hourly_data, device_property_id: dp.id,
                                              measured_at: base_time + 60*60,
                                              value: "123")
          @shd2 = create(:sensor_hourly_data, device_property_id: dp.id,
                                              measured_at: base_time + 2*60*60,
                                              value: "456")
          @shd3 = create(:sensor_hourly_data, device_property_id: dp.id,
                                              measured_at: base_time + 3*60*60,                                                  value: "789")

          @sd1 = create(:sensor_data, device_property_id: dp.id, value: "122",
                                      measured_at: base_time + 60*60)
          @sd2 = create(:sensor_data, device_property_id: dp.id, value: "455",
                                      measured_at: base_time + 2*60*60)
          @sd3 = create(:sensor_data, device_property_id: dp.id, value: "788",
                                      measured_at: base_time + 3*60*60)
          get "/api/sensor_data", sensor_id: dp.id, start: base_time.to_s, span: "daily"
        end

        include_examples "return_status_code", 200

        it "返されるJSONにSensorHourlyDataの値が設定されていること" do
          expect(last_response.body).to be_json_eql(
            {@shd1.measured_at.strftime("%Y-%m-%d %H:%M:%S") => @shd1.value.to_f.to_s,
             @shd2.measured_at.strftime("%Y-%m-%d %H:%M:%S") => @shd2.value.to_f.to_s,
             @sd3.measured_at.strftime("%Y-%m-%d %H:00:00") => @sd3.value.to_f.to_s,
             @shd3.measured_at.strftime("%Y-%m-%d %H:%M:%S") => @shd3.value.to_f.to_s,
          }.to_json)
        end
      end

      context "hourly" do
        before do
          dp = create(:sensor_dp)
          base_time = Time.now - 1*24*60*60 # 現在時刻の1日前

          @sd1 = create(:sensor_data, device_property_id: dp.id, measured_at: base_time + 60*60, value: "123")
          @sd2 = create(:sensor_data, device_property_id: dp.id, measured_at: base_time + 2*60, value: "456")
          @sd3 = create(:sensor_data, device_property_id: dp.id, measured_at: base_time + 3*60, value: "789")
          get "/api/sensor_data", sensor_id: dp.id, start: base_time.to_s, span: "hourly"
        end

        include_examples "return_status_code", 200

        it "返されるJSONにSensorDataの値が設定されていること" do
          avg = ((@sd2.value.to_f + @sd3.value.to_f) / 2.0).round
          expect(last_response.body).to be_json_eql(
            {@sd1.measured_at.strftime("%Y-%m-%d %H:%M:%S") => @sd1.value.to_f.to_s,
            @sd2.measured_at.strftime("%Y-%m-%d %H:%M:%S") => avg.to_f.to_s,
          }.to_json)
        end
      end
    end

    context "POST" do
      posted_data = { "10" => "measured_data" }
      before do
        create(:sensor_dp, id: posted_data.keys[0].to_i)
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
    context "GET" do
      before do
        base_time = Time.now - 3*24*60*60 # 現在時刻の3日前
        dp1 = create(:sensor_dp)
        @sa = create(:sensor_alert, device_property_id: dp1.id, measured_at: base_time)

        get "/api/sensor_alert", sensor_id: dp1.id, datetime: base_time.strftime("%Y-%m-%d %H:%M:%S")
      end

      include_examples "return_status_code", 200

      it "返されるJSONにSensorAlertの値が設定されていること" do
        expect(last_response.body).to be_json_eql("\"#{@sa.value}\"").at_path("value")
      end
    end

    context "POST" do
      posted_data = { "10" => { "value" => "val1", "min": "min1", "max": "max1" } }
      before do
        create(:sensor_dp, id: posted_data.keys[0].to_i)
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
  end

  describe "/api/operationへのアクセス" do
    context "GET" do
      before do
        @dp = create(:not_sensor_dp, gateway_id: 126)
        @op = create(:operation, device_property_id: @dp.id)

        get "/api/operation", gateway_id: @dp.gateway_id
      end

      include_examples "return_status_code", 200

      it "返されるJSONにOperationの値が設定されていること" do
        expect(last_response.body).to be_json_eql("\"#{@op.value}\"").at_path("#{@dp.id}/value")
      end
    end

    context "POST" do
      posted_data = { "10" => "operation_value" }
      before do
        create(:not_sensor_dp, id: posted_data.keys[0].to_i)
        user = create(:user)

        post "/api/operation", posted_data.to_json, { "rack.session" => { user_id: user.id }}
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
  end

  describe "/api/operation_statusへのアクセス" do
    context "GET" do
      before do
        @op = create(:operation)

        get "/api/operation_status", operation_id: @op.id
      end

      include_examples "return_status_code", 200

      it "返されるJSONにOperationの値が設定されていること" do
        expect(last_response.body).to be_json_eql("\"#{@op.value}\"").at_path("value")
      end

    end

    context "POST" do
      posted_data = { "10" => "0" }
      before do
        create(:operation, id: posted_data.keys[0].to_i)
        post "/api/operation_status", posted_data.to_json
      end

      include_examples "return_status_code", 201
      include_examples "return_body_message", "OK"

      it "Operationのstatusが設定されていること" do
        op = Operation.find(posted_data.keys[0].to_i)
        expect(op.status).to eq("0")
      end
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
                    "class_code" => "dummy",
                    "gateway_uid" => "aaa",
                    "device_uid" => "bbb"
    }

    before do
      Gateway.create(hardware_uid: posted_data["gateway_uid"])
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
      gateway = Gateway.where(hardware_uid: posted_data["gateway_uid"]).first
      device = Device.where(gateway_id: gateway.id).first
      expect(device.hardware_uid).to eq("bbb")
    end
  end

  describe "/api/controllerへのアクセス" do
    context "GET" do
      before do
        @dp1 = create(:not_sensor_dp, gateway_id: 12)
        @dp2 = create(:not_sensor_dp, gateway_id: 12)
        create(:operation, device_property_id: @dp1.id, status: 0)
        create(:operation, device_property_id: @dp2.id, status: 0)

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
        create(:sensor_dp, id: posted_data.keys[0].to_i)
        user = create(:user)

        post "/api/sensor", posted_data.to_json, { "rack.session" => { user_id: user.id }}
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
        send_device_property_id = 124 # 適当に選択したid

        create(:monitor_range, device_property_id: send_device_property_id, min_value: 101, max_value: 4321)
        create(:sensor_dp, id: send_device_property_id)

        get "/api/monitor", sensor_id: send_device_property_id
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
        create(:sensor_dp, id: posted_data.keys[0].to_i)
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

  describe "/api/sensor_data_sumへのアクセス" do
    before do
      base_time = Time.now - 3 * 24 * 60 * 60 # 現在時刻の3日前
      @sd1 = create(:sensor_data, device_property_id: "121", measured_at: base_time, value: "111")
      @sd2 = create(:sensor_data, device_property_id: "122", measured_at: base_time - 24 * 60 * 60, value: "222")

      get "/api/sensor_data_sum"
    end

    it "返されるテキストにSensorDataの値が設定されていること" do
      expect(last_response.body).to eq("#{@sd1.device_property_id} | #{@sd1.measured_at.strftime("%Y-%m-%d %H:00:00")}\n#{@sd2.device_property_id} | #{@sd2.measured_at.strftime("%Y-%m-%d %H:00:00")}\n")
    end
  end
end
