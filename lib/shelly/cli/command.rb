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
      class_option :help, :type => :boolean, :aliases => "-h", :desc => "Describe available tasks or one specific task"

      def initialize(*)
        super
        if options[:help]
          help(self.class.send(:retrieve_task_name, ARGV.dup))
          exit(0)
        end
      end
    end
  end
end
