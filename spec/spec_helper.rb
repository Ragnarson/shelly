require "rspec"
require "shelly"
require "helpers"
require "input_faker"
require "fakefs/spec_helpers"

RSpec.configure do |config|
  config.include RSpec::Helpers
  config.include FakeFS::SpecHelpers
end
