ENV["RACK_ENV"] = "test"

require File.join(File.dirname(__FILE__), "..", "main.rb")

require "rubygems"
require "sinatra"
require "rack/test"
require "rspec"
require "json_spec"

set :run, false
set :raise_errors, true

RSpec.configure do |config|
  config.include JsonSpec::Helpers
end

