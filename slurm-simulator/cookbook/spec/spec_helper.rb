require 'chefspec'

RSpec.configure do |config|
  config.platform = 'ubuntu' # the slurm-simulator node, ubuntu:22.04
  config.version = '22.04'
end
