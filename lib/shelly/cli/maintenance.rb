require 'shelly/cli/command'
require 'time'

module Shelly
  module CLI
    class Maintenance < Command
      namespace :maintenance
      include Helpers

      before_hook :logged_in?, :only => [:list, :start, :finish]
      class_option :cloud, :type => :string, :aliases => "-c",
        :desc => "Specify cloud"

      desc 'list', 'Recent application maintenance events'
      def list
        app = multiple_clouds(options[:cloud], 'maintenance list')
        maintenances = app.maintenances

        if maintenances.any?
          say 'Recent application maintenance events', :green
          say_new_line

          maintenances.each do |maintenance|
            started_at = Time.parse(maintenance['created_at']).
              strftime('%Y-%m-%d %H:%M:%S')
            finished_at = if maintenance['finished']
              Time.parse(maintenance['updated_at']).
                strftime('%Y-%m-%d %H:%M:%S')
            else
              'in progress'
            end

            say " * #{started_at} - #{finished_at}"
            say "   #{maintenance['description']}"
            say_new_line
          end
        else
          say "There are no maintenance events for #{app}"
        end
      end

      desc 'start DESCRIPTION', 'Start maintenance'
      def start(description = nil)
        app = multiple_clouds(options[:cloud], 'start')
        app.start_maintenance({:description => description})
        say "Maintenance has been started", :green
      rescue Client::ValidationException => exception
        exception.each_error { |error| say_error error, :with_exit => false }
      rescue Client::ConflictException => e
        say_error e[:message]
      end

      desc 'finish', 'Finish last maintenance'
      def finish
        app = multiple_clouds(options[:cloud], 'finish')
        app.finish_maintenance
        say "Maintenance has been finished", :green
      rescue Client::ValidationException => exception
        exception.each_error { |error| say_error error, :with_exit => false }
      rescue Client::ConflictException => e
        say_error e[:message]
      end
    end
  end
end
