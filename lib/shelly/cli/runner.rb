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
      rescue SystemExit; raise
      rescue Client::UnauthorizedException
        raise if debug?
        say_error "You are not logged in. To log in use: `shelly login`"
      rescue Client::GemVersionException => e
        raise if debug?
        say "Required shelly gem version: #{e.body["required_version"]}"
        say "Your version: #{VERSION}"
        say "Update shelly gem with `gem install shelly`"
        say_error "or `bundle update shelly` when using bundler"
      rescue Interrupt
        raise if debug?
        say_new_line
        say_error "[canceled]"
      rescue Client::APIException => e
        raise if debug?
        say_error "You have found a bug in the shelly gem. We're sorry.",
          :with_exit => false
        exit 1 unless e.request_id
        say_error <<-eos
You can report it to support@shellycloud.com by describing what you wanted
to do and mentioning error id #{e.request_id}.
        eos
      rescue Exception
        raise if debug?
        say_error "Unknown error, to see debug information run command with --debug"
      end
    end
  end
end
