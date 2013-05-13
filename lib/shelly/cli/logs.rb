require "shelly/cli/command"

module Shelly
  module CLI
    class Logs < Command
      namespace :logs
      include Helpers

      before_hook :logged_in?, :only => [:latest, :date]
      class_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"

      desc "latest", "Show latest application logs"
      method_option :limit, :type => :numeric, :aliases => "-n", :desc => "Amount of messages to show"
      method_option :from, :type => :string, :desc => "Time from which to find the logs"
      method_option :source, :type => :string, :aliases => "-s", :desc => "Limit logs to a single source, e.g. nginx"
      method_option :tail, :type => :boolean, :aliases => "-f", :desc => "Show new logs automatically"
      def latest
        cloud = options[:cloud]
        app = multiple_clouds(cloud, "logs latest")
        limit = options[:limit].to_i <= 0 ? 100 : options[:limit]
        query = {:limit => options[:limit], :source => options[:source]}
        query.merge!(:from => options[:from]) if options[:from]

        logs = app.application_logs(query)
        print_logs(logs)

        if options[:tail]
          app.application_logs_tail { |logs| print logs }
        end
      rescue Client::APIException => e
        raise e unless e.status_code == 416
        say_error "You have requested too many log messages. Try a lower number."
      end

      desc "date [DATE]", "Show logs from a specific day"
      method_option :source, :type => :string, :aliases => "-s", :desc => "Limit logs to a single source, e.g. nginx"
      def date(day = "today")
        cloud = options[:cloud]
        app = multiple_clouds(cloud, "logs date #{day}")

        query = {:date => day, :source => options[:source]}
        logs = app.application_logs(query)
        print_logs(logs)
      end
    end
  end
end
