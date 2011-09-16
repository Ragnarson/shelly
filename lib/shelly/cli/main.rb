require "shelly"
require "thor/group"
require "shelly/cli/account"
require "shelly/cli/apps"

module Shelly
  module CLI
    class Main < Thor
      include Thor::Actions
      register(Account, "account", "account <command>", "Manages your account")
      register(Apps, "apps", "apps <command>", "Manages your applications")

      map %w(-v --version) => :version
      desc "version", "Displays shelly version"
      def version
        say "shelly version #{Shelly::VERSION}"
      end

      desc "register", "Registers new user account on Shelly Cloud"
      def register
        invoke 'account:register'
      end
    end
  end
end
