require "yaml"
require "shelly/user"
require "shelly/cloudfile"

module Shelly
  module CLI
    class Users < Thor
      namespace :users
      include Helpers

      desc "list", "List users who have access to current application"
      def list
        say_error "Must be run inside your project git repository" unless App.inside_git_repository?
        @cloudfile = Shelly::Cloudfile.new
        @cloudfile.fetch_users.each do |app, users|
          say "Cloud #{app}:"
          users.each { |user| say "  #{user}" }
        end
      rescue Client::APIError => e
        say e.message
        exit 1
      end

      desc "add [EMAIL]", "Add new developer to applications defined in Cloudfile"
      def add(email = nil)
        say_error "Must be run inside your project git repository" unless App.inside_git_repository?
        user_email = email || ask_for_email({:guess_email => false})
        @cloudfile = Shelly::Cloudfile.new
        @user = Shelly::User.new
        @user.send_invitation(@cloudfile.clouds, user_email)
        say "Sending invitation to #{user_email}"
      rescue Client::APIError => e
        say e.message
        exit 1
      end

    end
  end
end

