$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'api'))
require 'airborne'
require 'hrlh'
Airborne.configure do |config|
  config.headers = {'HTTP_AUTHORIZATION' => 'Basic YXNkZjphc2RmYWRzZg=='}
  config.rack_app = HRLH::API
end
