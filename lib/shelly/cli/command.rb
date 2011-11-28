require "shelly"
require "thor"
require "thor/group"
require "thor/options"
require "thor/arguments"

module Shelly
  module CLI
    class Command < Thor
      include Helpers
      extend Hook
      class_option :debug, :type => :boolean, :desc => "Show debug information"
    end
  end
end
