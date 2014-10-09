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
### Web画面 ###
Web画面は現在ログイン画面のみで、他の機能と連携していません。

### API ###
以下のWeb APIを提供します。

* POST /api/device  
gatewayは、以下の形式のJSONデータをPOSTすることで、
各種sensorやcontrollerが接続されたdeviceを、
登録・更新することができます。


    { "hardware_uid": "Seriarl、MACなど"
      "class_group_code": "0x00",
      "class_code": "0x11",
      "properties":
      [
        { "property_code": "0xB0",
          "property_type": "sensor または controller"},

        ...

      ]
    }


* GET /api/sensor?gateway_id=xxx  
mobileは、指定したgatewayの配下にあるsensorのリストを、
以下のようなJSON形式で取得できます。
"yyy"、"zzz"はセンサーのidです。


    { "yyy":
      { "name": "キッチンのガス漏れセンサー",
        "property_name": "Detection threshold level"}

      ... ,

      "zzz"
      { "name": "リビングの温度計"
        "data-unit": "degree Celsius",
        "property_name": "Measured temperature value" }

      ...

    }


* POST /api/sensor  
mobileは、以下の形式のJSONデータをPOSTすることで、
センサーの名前を登録・更新することができます。


    { "xxx": { "name": "センサーの名前"} }


* GET /api/threshold?sensor_id=xxx  
mobileは、指定したセンサーの監視値を以下のようなJSON形式で取得できます。


    { "min": "下限値", "max": "上限値"}


* POST /api/threshold  
mobileは、以下の形式のJSONデータをPOSTすることで、
センサーの監視値を登録・更新することができます。


    { "sensor_id": "xxx", "min": "下限値", "max": "上限値"}





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
