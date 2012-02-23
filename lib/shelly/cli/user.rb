require "shelly/cli/command"

module Shelly
  module CLI
    class User < Command
      namespace :user
      include Helpers

      before_hook :logged_in?, :only => [:list, :add, :delete]
      before_hook :cloudfile_present?, :only => [:list, :add, :delete]

      desc "list", "List users with access to clouds defined in Cloudfile"
      def list
        @cloudfile = Cloudfile.new
        @cloudfile.clouds.each do |cloud|
          begin
            @app = App.new(cloud)
            collaborations = @app.collaborations.sort_by { |c| c["email"] }.
              partition { |c| c["active"] }.flatten
            say "Cloud #{cloud}:"
            collaborations.each do |c|
              output = "  #{c["email"]}"
              output += " (invited)" unless c["active"]
              say output
            end
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

      desc "delete [EMAIL]", "Remove developer from clouds defined in Cloudfile"
      def delete(email = nil)
        @cloudfile = Cloudfile.new
        @user = Shelly::User.new
        user_email = email || ask_for_email({:guess_email => false})
        @cloudfile.clouds.each do |cloud|
          begin
            @user.delete_collaboration(cloud, user_email)
            say "User #{user_email} deleted from cloud #{cloud}"
          rescue Client::NotFoundException => e
            case e.resource
            when :cloud
              say_error "You have no access to '#{cloud}' cloud defined in Cloudfile"
            when :user
              say_error "User '#{user_email}' not found", :with_exit => false
              say_error "You can list users with `shelly user list`"
            else raise
            end
          end
        end
      end

    end
  end
end
