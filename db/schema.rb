# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20141111083446) do

  create_table "device_properties", force: :cascade do |t|
    t.integer  "gateway_id"
    t.integer  "device_id"
    t.string   "name"
    t.boolean  "sensor"
    t.string   "class_group_code", limit: 4
    t.string   "class_code",       limit: 4
    t.string   "property_code",    limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
  end

  create_table "devices", force: :cascade do |t|
    t.integer  "gateway_id"
    t.string   "hardware_uid"
    t.string   "name"
    t.string   "class_group_code", limit: 4
    t.string   "class_code",       limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "gateways", force: :cascade do |t|
    t.string   "hardware_uid"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "monitor_ranges", force: :cascade do |t|
    t.integer  "device_property_id"
    t.string   "min_value"
    t.string   "max_value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "operations", force: :cascade do |t|
    t.integer  "device_property_id"
    t.string   "value"
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sensor_alerts", force: :cascade do |t|
    t.integer  "device_property_id"
    t.string   "value"
    t.string   "monitor_min_value"
    t.string   "monitor_max_value"
    t.datetime "measured_at"
  end

  create_table "sensor_datas", force: :cascade do |t|
    t.integer  "device_property_id"
    t.string   "value"
    t.datetime "measured_at"
  end

  add_index "sensor_datas", ["measured_at", "device_property_id"], name: "index_sensor_datas_on_measured_at"

  create_table "sensor_hourly_datas", force: :cascade do |t|
    t.integer  "device_property_id"
    t.string   "value"
    t.string   "min_3rd_value"
    t.string   "max_3rd_value"
    t.datetime "measured_at"
  end

  add_index "sensor_hourly_datas", ["measured_at", "device_property_id"], name: "index_sensor_hourly_datas_on_mesured_at"

  create_table "user_gateway_relations", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "gateway_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: :cascade do |t|
    t.string   "login_name"
    t.string   "password_hash"
    t.string   "email"
    t.string   "nickname"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
