require "shelly/cli/command"

module Shelly
  module CLI
    class User < Command
      namespace :user
      include Helpers

      before_hook :logged_in?, :only => [:list, :add, :delete]
      class_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"

      desc "list", "List users with access to clouds defined in Cloudfile"
      def list
        app = multiple_clouds(options[:cloud], "list")
        say "Cloud #{app}:"
        app.active_collaborations.each { |c| say "  #{c["email"]}" }
        app.inactive_collaborations.each { |c|
          say "  #{c["email"]} (invited)" }
      rescue Client::NotFoundException => e
        raise unless e.resource == :cloud
        say_error "You have no access to '#{app}' cloud defined in Cloudfile"
      end

      desc "add [EMAIL]", "Add new developer to clouds defined in Cloudfile"
      def add(email = nil)
        user = Shelly::User.new
        app = multiple_clouds(options[:cloud], "add")
        user_email = email || ask_for_email({:guess_email => false})
        user.send_invitation(app.to_s, user_email)
        say "Sending invitation to #{user_email} to work on #{app}", :green
      rescue Client::ValidationException => e
        if e.errors.include?(["email", "#{email} has already been taken"])
          say_error "User #{email} is already in the cloud #{app}", :with_exit => false
        else
          e.each_error { |error| say_error error, :with_exit => false }
          exit 1
        end
      rescue Client::NotFoundException => e
        raise unless e.resource == :cloud
        say_error "You have no access to '#{app}' cloud defined in Cloudfile"
      end

      desc "delete [EMAIL]", "Remove developer from clouds defined in Cloudfile"
      def delete(email = nil)
        user = Shelly::User.new
        app = multiple_clouds(options[:cloud], "delete")
        user_email = email || ask_for_email({:guess_email => false})
        user.delete_collaboration(app.to_s, user_email)
        say "User #{user_email} deleted from cloud #{app}"
      rescue Client::ConflictException => e
        say_error e[:message]
      rescue Client::NotFoundException => e
        case e.resource
        when :cloud
          say_error "You have no access to '#{app}' cloud defined in Cloudfile"
        when :user
          say_error "User '#{user_email}' not found", :with_exit => false
          say_error "You can list users with `shelly user list`"
        else raise
        end
      end

    end
  end
end
