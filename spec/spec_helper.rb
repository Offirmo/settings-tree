$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

# we need other gems : load them via bundler :
require "rubygems"
require "bundler/setup"
# now our dependencies are available.

require 'rspec'
require 'settings_tree'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}


# I add some display to clearly mark the beginning of the tests
puts "*\n"*12

RSpec.configure do |config|
  
end
