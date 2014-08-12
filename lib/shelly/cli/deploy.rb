require "shelly/cli/command"
require "time"

module Shelly
  module CLI
    class Deploy < Command
      namespace :deploy
      include Helpers

      before_hook :logged_in?, :only => [:list, :show]
      before_hook :inside_git_repository?, :only => [:pending]
      class_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"

      desc "list", "Lists deploy logs"
      def list
        app = multiple_clouds(options[:cloud], "deploy list")
        logs = app.deploy_logs
        unless logs.empty?
          say "Available deploy logs", :green
          logs.each do |log|
            if log['author'].present? && log['commit_sha'].present?
              log_line = " * #{log['created_at']} #{log['commit_sha'][0..6]} by #{log['author']}"
            elsif log['author'].present?
              log_line = " * #{log['created_at']} redeploy by #{log['author']}"
            else
              log_line = " * #{log['created_at']}"
            end
            message = log["failed"] ? "#{log_line} (failed)" : log_line
            say(message, nil, true)
          end
        else
          say "No deploy logs available"
        end
      end

      desc "show LOG", "Show specific deploy log"
      def show(log = nil)
        specify_log(log)
        app = multiple_clouds(options[:cloud], "deploy show #{log}")
        content = app.deploy_log(log)
        unless content.empty?
          say "Log for deploy done on #{content["created_at"]}", :green
          if content["bundle_install"]
            say("Bundle install", :green); say(content["bundle_install"])
          end
          if content["before_migrate"]
            say("Before migrate hook", :green); say(content["before_migrate"])
          end
          if content["db_migrate"]
            say("Rake db:migrate", :green); say(content["db_migrate"])
          end
          if content["before_symlink"]
            say("Before symlink hook", :green); say(content["before_symlink"])
          end
          if content["before_restart"]
            say("Before restart hook", :green); say(content["before_restart"])
          end
          if content["on_restart"]
            say("On restart hook", :green); say(content["on_restart"])
          end
          if content["delayed_job"]
            say("Starting delayed job", :green); say(content["delayed_job"])
          end
          if content["sidekiq"]
            say("Starting sidekiq", :green); say(content["sidekiq"])
          end
          if content["clockwork"]
            say("Starting clockwork", :green); say(content["clockwork"])
          end
          if content["processes"]
            say("Starting processes", :green); say(content["processes"])
          end
          if content["thin_restart"]
            say("Starting thin", :green); say(content["thin_restart"])
          end
          if content["puma_restart"]
            say("Starting puma", :green); say(content["puma_restart"])
          end
          if content["after_restart"]
            say("After restart hook", :green); say(content["after_restart"])
          end
          if content["whenever"]
            say("Whenever", :green); say(content["whenever"])
          end
          if content["after_successful_deploy_hook"]
            say("Running after successful deploy hook", :green)
            say(content["after_successful_deploy_hook"])
          end
        else
          say_error("There was an error and log is not available", :with_exit => false)
          say_error("Please contact our support https://shellycloud.com/support")
        end
      rescue Client::NotFoundException => e
        raise unless e.resource == :log
        say_error "Log not found, list all deploy logs using `shelly deploys list --cloud=#{app.code_name}`"
      end

      desc "pending", "Show commits which haven't been deployed yet"
      def pending
        app = multiple_clouds(options[:cloud], "deploy pending")
        say "Running: git fetch shelly"
        say_new_line
        app.git_fetch_remote
        if app.deployed?
          commits = app.pending_commits
          if commits.present?
            say "Commits which are not deployed to Shelly Cloud"
            say commits
          else
            say "All changes are deployed to Shelly Cloud", :green
          end
        else
          say_error "No commits to show. Application hasn't been deployed yet"
        end
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
