require "shelly/cli/command"

module Shelly
  module CLI
    class User < Command
      namespace :user
      include Helpers

      before_hook :logged_in?, :only => [:list, :add]
      before_hook :inside_git_repository?, :only => [:list, :add]
      before_hook :cloudfile_present?, :only => [:list, :add]

      desc "list", "List users with access to clouds defined in Cloudfile"
      def list
        @cloudfile = Cloudfile.new
        @cloudfile.clouds.each do |cloud|
          begin
            @app = App.new(cloud)
            say "Cloud #{cloud}:"
            @app.users.each { |user| say "  #{user["email"]}" }
          rescue Client::APIError => e
            if e.not_found?
              say_error "You have no access to '#{cloud}' cloud defined in Cloudfile", :with_exit => false
            else
              say_error e.message, :with_exit => false
            end
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
          rescue Client::APIError => e
            if e.validation? && e.errors.include?(["email", "#{email} has already been taken"])
              say_error "User #{email} is already in the cloud #{cloud}", :with_exit => false
            elsif e.not_found?
              say_error "You have no access to '#{cloud}' cloud defined in Cloudfile", :with_exit => false
            elsif e.validation?
              e.each_error { |error| say_error error, :with_exit => false }
              exit 1
            else
              say_error e.message, :with_exit => false
            end
          else
            say "Sending invitation to #{user_email} to work on #{cloud}", :green
          end
        end
      end
    end
  end
end
