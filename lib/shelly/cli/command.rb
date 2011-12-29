require "shelly"
require "thor"
require "thor/thor"
require "thor/group"
require "thor/options"
require "thor/arguments"
require "thor/basic"

module Shelly
  module CLI
    class Command < Thor
      include Helpers
      class_option :debug, :type => :boolean, :desc => "Show debug information"
    end
  end
end
