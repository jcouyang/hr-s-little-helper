$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'api'))
require 'airborne'
require 'hrlh'
Airborne.configure do |config|
  config.rack_app = HRLH::API
end
