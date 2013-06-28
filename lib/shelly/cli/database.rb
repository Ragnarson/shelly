require "shelly/cli/command"
require "time"

module Shelly
  module CLI
    class Database < Command
      namespace :database
      include Helpers
      before_hook :logged_in?, :only => [:reset]
      class_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"

      desc "reset KIND", "Reset database"
      long_desc %{
        Removes all objects from the database
        KIND - Database kind. Possible values are: postgresql or mongodb
      }
      def reset(kind)
        app = multiple_clouds(options[:cloud], "database reset")
        say "You are about to reset database #{kind} for cloud #{app}"
        say "All database objects and data will be removed"
        ask_to_reset_database
        app.reset_database(kind)
      end
    end
  end
end
