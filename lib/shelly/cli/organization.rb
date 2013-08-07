require "shelly/cli/command"

module Shelly
  module CLI
    class Organization < Command
      namespace :organization
      include Helpers

      before_hook :logged_in?, :only => [:list, :add]

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

      method_option "redeem-code", :type => :string, :aliases => "-r",
        :desc => "Redeem code for free credits"
      desc "add", "Add a new organization"
      def add
        create_new_organization(options)
      rescue Client::ValidationException => e
        e.each_error { |error| say_error error, :with_exit => false }
        exit 1
      end
    end
  end
end
