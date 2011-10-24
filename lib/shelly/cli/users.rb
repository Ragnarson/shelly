require "yaml"
require "shelly/user"

module Shelly
  module CLI
    class Users < Thor
      namespace :users
      include Helpers

      desc "list", "List users who have access to current application"
      def list
        say_error "Must be run inside your project git repository" unless App.inside_git_repository?
        code_names = YAML.load(File.open(File.join(Dir.pwd, "Cloudfile"))).keys
        @app = Shelly::App.new
        response = @app.users(code_names.sort)
        response.each do |app|
          app = JSON.parse(app)
          say "Cloud #{app['code_name']}:"
          app['users'].each do |user|
            say "  #{user['email']} (#{user['name']})"
          end
        end
      rescue Client::APIError => e
        say e.message
        exit 1
      end

    end
  end
end

