require 'chefspec'

module FileStubs
  # Stubs File.<method> for one path; every other path still hits the real filesystem.
  def stub_file(method, path, result)
    allow(File).to receive(method).and_call_original
    allow(File).to receive(method).with(path).and_return(result)
  end
end

RSpec.configure do |config|
  config.platform = 'debian' # kindest/node
  config.version = '13'
  config.include FileStubs
end
