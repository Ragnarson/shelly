require "rspec"
require "helpers"
require "shelly"
require "io_ext"
require "input_faker"
require "fakefs/safe"
require "fakefs/spec_helpers"

RSpec.configure do |config|
  config.include RSpec::Helpers
end
