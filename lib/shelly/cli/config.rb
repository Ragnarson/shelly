require "shelly/cli/command"

module Shelly
  module CLI
    class Config < Command
      include Thor::Actions
      include Helpers

      desc "list", "List configuration files"
      def list
        logged_in?
        say_error "No Cloudfile found" unless Cloudfile.present?
        cloudfile = Cloudfile.new
        cloudfile.clouds.each do |cloud|
          @app = App.new(cloud)
          begin
            configs = @app.configs
            unless configs.empty?
              say "Configuration files for #{cloud}", :green
              user_configs = configs.find_all { |config| config["created_by_user"] }
              unless user_configs.empty?
                say "Custom configuration files:"
                user_configs.each { |config| say " * #{config["path"]}" }
              else
                say "You have no custom configuration files."
              end

              shelly_configs = configs - user_configs
              unless shelly_configs.empty?
                say "Following files are created by Shelly Cloud:"
                shelly_configs.each { |config| say " * #{config["path"]}" }
              end
            else
              say "Cloud #{cloud} has no configuration files"
            end
          rescue Client::APIError => e
            if e.unauthorized?
              say_error "You have no access to '#{@app.code_name}' cloud defined in Cloudfile"
            else
              say_error e.message
            end
          end
        end
      end

    end
  end
end