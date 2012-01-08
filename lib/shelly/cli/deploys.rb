require "shelly/cli/command"
require "time"

module Shelly
  module CLI
    class Deploys < Command
      namespace :deploys
      include Helpers

      before_hook :logged_in?, :only => [:list, :show]
      before_hook :cloudfile_present?, :only => [:list, :show]

      desc "list", "Lists deploy logs"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def list
        multiple_clouds(options[:cloud], "deploys list")
        logs = @app.deploy_logs
        unless logs.empty?
          say "Available deploy logs", :green
          logs.each do |log|
            log["failed"] ? say(" * #{log["created_at"]} (failed)") : say(" * #{log["created_at"]}")
          end
        else
          say "No deploy logs available"
        end
      rescue Client::NotFoundException => e
        raise unless e.resource == :cloud
        say_error "You have no access to '#{@app}' cloud defined in Cloudfile"
      end

      desc "show LOG", "Show specific deploy log"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def show(log = nil)
        specify_log(log)
        multiple_clouds(options[:cloud], "deploys show #{log}")
        content = @app.deploy_log(log)
        say "Log for deploy done on #{content["created_at"]}", :green
        if content["bundle_install"]
          say("Starting bundle install", :green); say(content["bundle_install"])
        end
        if content["whenever"]
          say("Starting whenever", :green); say(content["whenever"])
        end
        if content["callbacks"]
          say("Starting callbacks", :green); say(content["callbacks"])
        end
        if content["delayed_job"]
          say("Starting delayed job", :green); say(content["delayed_job"])
        end
        if content["thin_restart"]
          say("Starting thin", :green); say(content["thin_restart"])
        end
      rescue Client::NotFoundException => e
        case e.resource
        when :cloud
          say_error "You have no access to '#{@app.code_name}' cloud defined in Cloudfile"
        when :log
          say_error "Log not found, list all deploy logs using  `shelly deploys list --cloud=#{@app.code_name}`"
        else raise
        end
      end

      no_tasks do
        def specify_log(log)
          unless log
            say_error "Specify log by passing date value or to see last log use:", :with_exit => false
            say "  shelly deploys show last"
            exit 1
          end
        end
      end
    end
  end
end
