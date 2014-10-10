rubyiot_server
==============
このソフトウェアは、住宅に設置されたセンサーの情報を収集したり、
機器を操作したりする、いわゆるIoTのサーバーを、
Rubyで実装したサンプルです。
開発にあたって、ECHONETの規格を少し意識しています。

全体像
------
このソフトウェアは、IoTをRubyで実装したサンプルの一部で、
全体は下記のような構成になっています。

    [device] - [gateway] - [server] - [mobile]
      ├ [sensor]
      └ [controller]

* device  
環境を測定する専用機器や、家電そのもの、家電のリモコンなどを想定しています。
デバイスに接続、もしくは内蔵されたsensorの測定値をgatewayに送信したり、
gatewayから送られてきた操作の命令に従って、各種機器のOn/Offなど、
controllerを制御します。
* gateway  
住宅ごとに1台から数台設置する、deviceとインターネットを接続する装置を
想定しています。
deviceから送られてきた情報を蓄積およびserverに送信したり、
mobileやserverから送られてきた操作の命令を、deviceに転送したりします。
* server  
たくさんのgatewayから送られてきた情報を蓄積して、
複数のgatewayに渡る情報をユーザーに提供したり、
mobileから送られてきた操作の命令を、適切なgatewayに転送したりします。
* mobile  
スマートフォンなどから、住宅の環境を確認したり、家電などを操作します。

serverの機能
------------
### Web画面
Web画面は現在ログイン画面のみで、他の機能と連携していません。

### API
以下のWeb APIを提供します。

* POST /api/device  
  * 機能: sensorやcontrollerが接続されたdeviceを、登録・更新する。
  * アクセス: gateway => server
  * POSTデータ: 以下のJSON形式のデータ  
  （propertiesのkeyはproperty_code。
  各codeはECHONET機器オブジェクト詳細規定による。）

            { "hardware_uid": "<Seriarl、MACなど>"
              "class_group_code": "0x00",
              "class_code": "0x00",
              "properties":
              { "0x00": "< sensor | controller >",

                ...

              }
            }

  * 応答データ: 以下のJSON形式のデータ  
  （1階層目のkeyはserverで発行するdevice_id。
  2階層目のkeyはproperty_code。
  valueはserverで発行するsensor_idまたはcontroller_id。）

            { "xxx":
              { "0x00": "yyy",

                ...

              }
            }

* POST /api/sensor  
  * 機能: センサーの名前を登録・更新する。
  * アクセス: mobile => server
  * POSTデータ: 以下のJSON形式のデータ
  （keyの"xxx"はserverで管理するsensor_id）

            { "xxx": { "name": "センサーの名前" } }

* GET /api/sensor?gateway_id=xxx  
  * 機能: 指定したgatewayの配下にあるsensorのリストを取得する。
  * アクセス: mobile => server
  * クエリ: gateway_id
  * GETデータ: 以下のJSON形式のデータ  
  （1階層目のkeyの"yyy"、"zzz"は、serverで管理するsensor_id）

            { "yyy":
              { "name": "キッチンのガス漏れセンサー",
                "property_name": "Detection threshold level" },

              ...

              "zzz":
              { "name": "リビングの温度計"
                "data-unit": "degree Celsius",
                "property_name": "Measured temperature value" },

              ...

            }

* POST /api/monitor  
  * 機能: センサーの監視値（上限値・下限値）を登録・更新する。
  * アクセス: mobile, gateway => server
  * POSTデータ: 以下の形式のJSONデータ  
  （1階層目のkeyの"xxx"はserverで管理するsensor_id）

            { "xxx": { "min": "下限値", "max": "上限値" } }

* GET /api/monitor?sensor_id=xxx  
  * 機能: センサーの監視値（上限値・下限値）を取得する。
  * アクセス: mobile, gateway => server
  * クエリ: sensor_id
  * GETデータ: 以下のJSON形式のデータ

            { "min": "下限値", "max": "上限値" }

* POST /api/sensor_data
  * 機能: センサーの測定データを登録する。
  * アクセス: gateway => server
  * POSTデータ: 以下の形式のJSONデータ
  （keyの"xxx"はserverで管理するsensor_id）

            { "xxx": "測定値" }

* GET /api/sensor_data?sensor_id=xxx&start=2014-10-10+12:00:00&span=daily  
  * 機能: serverに蓄積されたセンサーの測定データを取得する。
  * アクセス: mobile => server
  * クエリ: sensor_id, start（取得する時刻範囲の開始時刻）,  
    span（5-minutely, hourly, daily, weekly, monthly, yearlyのいずれか。
    5-minutely, hourlyはstartが48時間以上前の場合は指定できない。）
  * GETデータ: 以下のJSON形式のデータ
  （測定時刻の間隔はspanによって、件数が366件以下になるように調整）

            { "測定時刻": "測定値", "測定時刻": "測定値", ... }

* GET /api/sensor_aleart?sensor_id=xxx&datetime=2014-10-10+12:00:00  
  * 機能: 現在もしくは指定した時刻の測定値が、異常値であったかを取得する。
  * アクセス: mobile => server
  * クエリ: sensor_id, datetime（指定しない場合は現在時刻）
  * GETデータ: 以下のJSON形式のデータ

            { "aleart": "< 0 | 1 >", "value": "測定値",
              "min": "下限値", "max": "上限値" }




動作環境
--------
最低限、以下のソフトウェアがインストールされている必要があります。
* Ruby 2.1.3
* SQLite 3

ライセンス
----------
Copyright(C) 2014 Japan OSS Promotion Forum

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
