require 'chefspec'

RSpec.configure do |config|
  config.platform = 'redhat' # the admin node, ubi9
  config.version = '9'
end
