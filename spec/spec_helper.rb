if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
end

require "rspec"
require "shelly"
require "helpers"
require "input_faker"
require "fakefs/spec_helpers"
require "fakeweb"
require "launchy"
require "rake"

ENV['THOR_COLUMNS'] = "180"
FakeWeb.allow_net_connect = false

RSpec.configure do |config|
  config.include RSpec::Helpers
  config.include FakeFS::SpecHelpers
end

# FakeFS doesn't support executable? class method
class FakeFS::File
  def self.executable?(file)
    true
  end
end
