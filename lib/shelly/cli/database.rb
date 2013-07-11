require "shelly/cli/command"
require "time"

module Shelly
  module CLI
    class Database < Command
      namespace :database
      include Helpers
      before_hook :logged_in?, :only => [:reset, :tunnel]
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
      rescue Client::ConflictException
        say_error "Cloud #{app} wasn't deployed properly. Cannot reset database."
      end

      desc "tunnel KIND", "Setup tunnel to given database"
      method_option :port, :type => :string, :aliases => "-p",
        :desc => "Local port on which tunnel will be set up"
      def tunnel(kind)
        app = multiple_clouds(options[:cloud], "database tunnel")
        local_port = options[:port] || 9900
        conn = app.tunnel_connection(kind)
        say "Connection details", :green
        say "host:          localhost"
        say "port:          #{local_port}"
        say "database name: #{conn['user']}"
        say "username:      #{conn['user']}"
        say "password:      #{conn['password']}"
        app.setup_tunnel(conn, local_port)
      end
    end
  end
end
