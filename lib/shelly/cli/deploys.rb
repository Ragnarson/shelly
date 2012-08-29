require "shelly/cli/command"
require "time"

module Shelly
  module CLI
    class Deploys < Command
      namespace :deploys
      include Helpers

      before_hook :logged_in?, :only => [:list, :show]
      class_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"

      desc "list", "Lists deploy logs"
      def list
        app = multiple_clouds(options[:cloud], "deploys list")
        logs = app.deploy_logs
        unless logs.empty?
          say "Available deploy logs", :green
          logs.each do |log|
            log_line = " * #{log['created_at']} #{log['commit_sha']} by #{log['author']}"
            message = log["failed"] ? "#{log_line} (failed)" :log_line
            say(message, nil, true)
          end
        else
          say "No deploy logs available"
        end
      end

      desc "show LOG", "Show specific deploy log"
      def show(log = nil)
        specify_log(log)
        app = multiple_clouds(options[:cloud], "deploys show #{log}")
        content = app.deploy_log(log)
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
        raise unless e.resource == :log
        say_error "Log not found, list all deploy logs using `shelly deploys list --cloud=#{app.code_name}`"
      end

      no_tasks do
        def specify_log(log)
          unless log
            say_error "Specify log by passing date value or to see last log use:", :with_exit => false
            say "`shelly deploys show last`"
            exit 1
          end
        end
      end
    end
  end
end
