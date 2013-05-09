require "shelly/cli/command"

module Shelly
  module CLI
    class Organization < Command
      namespace :organization
      include Helpers

      before_hook :logged_in?, :only => [:list]

      desc "list", "Lists organizations"
      def list
        user = Shelly::User.new
        organizations = user.organizations
        say "You have access to the following organizations and clouds:", :green
        say_new_line
        organizations.each do |organization|
          say organization.name, :green
          if organization.apps.present?
            print_table(apps_table(organization.apps), :ident => 2, :colwidth => 35)
          else
            print_wrapped "No clouds", :ident => 2
          end
        end
      end
    end
  end
end
