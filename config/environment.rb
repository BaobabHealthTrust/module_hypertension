# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.5' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  
	config.gem 'warden'
	config.gem 'devise'
	
  config.time_zone = 'UTC'
  
	config.action_controller.session = {
		:session_key => 'bart_session',
		:secret      => '8sgdhr431ba87cfd9bea177ba3d344a67acb0f179753f37d28db8bd102134261cdb4b1dbacccb126435631686d66e148a203fac1c5d71eea6abf955a66a472ce'
	}  
end

require 'bantu_soundex'
require 'composite_primary_keys'
