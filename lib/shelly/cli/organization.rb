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
        organizations = user.organizations_with_apps
        say "You have access to the following organizations and clouds:", :green
        say_new_line
        organizations.each do |organization|
          say organization.name, :green
          if organization.apps.present?
            apps_table = organization.apps.map do |app|
              state = app.state
              msg = if state == "deploy_failed" || state == "configuration_failed"
                " (deployment log: `shelly deploys show last -c #{app["code_name"]}`)"
              end
              [app.to_s, "|  #{state.humanize}#{msg}"]
            end
            print_table(apps_table, :ident => 2, :colwidth => 35)
          else
            print_wrapped "No clouds", :ident => 2
          end
        end
      end
    end
  end
end
