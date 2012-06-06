require "shelly/cli/command"

module Shelly
  module CLI
    class Files < Command
      namespace :files
      include Helpers

      before_hook :logged_in?, :only => [:upload, :download]
      before_hook :require_rsync, :only => [:upload, :download]
      class_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"

      desc "upload PATH", "Upload files to persisted data storage"
      def upload(path)
        app = multiple_clouds(options[:cloud], "upload #{path}")
        app.upload(path)
      rescue Client::NotFoundException => e
        raise unless e.resource == :cloud
        say_error "You have no access to '#{app}' cloud defined in Cloudfile"
      rescue Client::ConflictException
        say_error "Cloud #{app} is not running. Cannot upload files."
      end

      desc "download [SOURCE_PATH] [DEST_PATH]", "Download files from persitent data storage"
      def download(relative_source = ".", destination = ".")
        app = multiple_clouds(options[:cloud], "download #{relative_source} #{destination}")
        app.download(relative_source, destination)
      rescue Client::NotFoundException => e
        raise unless e.resource == :cloud
        say_error "You have no access to '#{app}' cloud defined in Cloudfile"
      rescue Client::ConflictException
        say_error "Cloud #{app} is not running. Cannot download files."
      end

      no_tasks do
        def require_rsync
          unless command_exists?("rsync")
            say_error "You need to install rsync in order to use `shelly upload`"
          end
        end
      end
    end
  end
end
