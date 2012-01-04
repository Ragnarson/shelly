require "shelly/cli/main"

module Shelly
  module CLI
    class Runner < Thor::Shell::Basic
      include Helpers
      attr_accessor :args

      def initialize(args = [])
        super()
        @args = args
      end

      def debug?
        args.include?("--debug") || ENV['SHELLY_DEBUG'] == "true"
      end

      def start
        Shelly::CLI::Main.start(args)
      rescue Interrupt => e
        say_new_line
        say_error "[canceled]"
      rescue => e
        raise e if debug?
        say_error "Unknown error, to see debug information run command with --debug"
      end
    end
  end
end
