ENV["RACK_ENV"] = "test"
require "simplecov"
SimpleCov.start do
  add_filter "/bundle/"
end

require File.join(File.dirname(__FILE__), "..", "main.rb")

require "rubygems"
require "sinatra"
require "rack/test"
require "rspec"
require "json_spec"
require "factory_girl"
require "database_rewinder"

# factory_girlのfactoryを読み込む
Dir[File.join(File.dirname(__FILE__), "factories", "*.rb")].each do |file|
  require file
end

set :run, false
set :raise_errors, true

RSpec.configure do |config|
  config.include JsonSpec::Helpers
  config.include Rack::Test::Methods
  config.include FactoryGirl::Syntax::Methods

  config.before :suite do
    DatabaseRewinder.clean_all
  end

  config.after :each do
    DatabaseRewinder.clean
  end
end
