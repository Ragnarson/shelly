require "shelly/cli/command"

module Shelly
  module CLI
    class User < Command
      namespace :user
      include Helpers

      before_hook :logged_in?, :only => [:list, :add]
      before_hook :cloudfile_present?, :only => [:list, :add]

      desc "list", "List users with access to clouds defined in Cloudfile"
      def list
        @cloudfile = Cloudfile.new
        @cloudfile.clouds.each do |cloud|
          begin
            @app = App.new(cloud)
            say "Cloud #{cloud}:"
            @app.users.each { |user| say "  #{user["email"]}" }
          rescue Client::NotFoundException => e
            raise unless e.resource == :cloud
            say_error "You have no access to '#{cloud}' cloud defined in Cloudfile"
          end
        end
      end

      desc "add [EMAIL]", "Add new developer to clouds defined in Cloudfile"
      def add(email = nil)
        @cloudfile = Cloudfile.new
        @user = Shelly::User.new
        user_email = email || ask_for_email({:guess_email => false})
        @cloudfile.clouds.each do |cloud|
          begin
            @user.send_invitation(cloud, user_email)
            say "Sending invitation to #{user_email} to work on #{cloud}", :green
          rescue Client::ValidationException => e
            if e.errors.include?(["email", "#{email} has already been taken"])
              say_error "User #{email} is already in the cloud #{cloud}", :with_exit => false
            else
              e.each_error { |error| say_error error, :with_exit => false }
              exit 1
            end
          rescue Client::NotFoundException => e
            raise unless e.resource == :cloud
            say_error "You have no access to '#{cloud}' cloud defined in Cloudfile"
          end
        end
      end
    end
  end
end
