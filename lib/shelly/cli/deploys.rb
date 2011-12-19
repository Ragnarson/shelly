require "shelly/cli/command"
require "time"

module Shelly
  module CLI
    class Deploys < Command
      namespace :deploys
      include Helpers

      desc "list", "Lists deploy logs"
      def list(cloud = nil)
        logged_in?
        say_error "No Cloudfile found" unless Cloudfile.present?
        multiple_clouds(cloud, "deploy list", "Select cloud to view deploy logs using:")
        logs = @app.deployment_logs
        unless logs.empty?
          say "Available deploy logs", :green
          logs.each do |log|
            log["failed"] ? say(" * #{log["created_at"]} (failed)") : say(" * #{log["created_at"]}")
          end
        else
          say "No deploy logs available"
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
