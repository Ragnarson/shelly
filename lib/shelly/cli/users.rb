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
        @cloudfile.fetch_users.each { |line| say line }
      rescue Client::APIError => e
        say e.message
        exit 1
      end

    end
  end
end
