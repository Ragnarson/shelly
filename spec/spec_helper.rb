require "rspec"
require "shelly"
require "helpers"
require "input_faker"
require "fakefs/spec_helpers"
require "fakeweb"

ENV['THOR_COLUMNS'] = "180"
FakeWeb.allow_net_connect = false

RSpec.configure do |config|
  config.include RSpec::Helpers
  config.include FakeFS::SpecHelpers
end

