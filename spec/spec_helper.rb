if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
end

# Psych is required here to make sure it will be used as default
# yaml engine when running tests (required by cloudfile_spec:49)
require 'psych' if RUBY_VERSION >= "1.9"
require "rspec"
require "shelly"
require "helpers"
require "input_faker"
require "fakefs/spec_helpers"
require "fakeweb"
require "launchy"

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

