require "shelly/cli/command"

module Shelly
  module CLI
    class File < Command
      namespace :file
      include Helpers

      before_hook :logged_in?, :only => [:upload, :download, :delete]
      before_hook :require_rsync, :only => [:upload, :download]
      class_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"

      desc "list [PATH]", "List files in given path"
      def list(path = "/")
        app = multiple_clouds(options[:cloud], "file list #{path}")
        app.list_files(path)
      rescue Client::ConflictException
        say_error "Cloud #{app} wasn't deployed properly. Cannot list files."
      end

      desc "upload PATH", "Upload files to persistent data storage"
      def upload(path)
        app = multiple_clouds(options[:cloud], "file upload #{path}")
        app.upload(path)
      rescue Client::ConflictException
        say_error "Cloud #{app} wasn't deployed properly. Cannot upload files."
      end

      desc "download [SOURCE_PATH] [DEST_PATH]", "Download files from persistent data storage"
      long_desc %{
        Download files from persistent data storage.\n
        SOURCE_PATH - optional source directory or file.\n
        DEST_PATH - optional destination where files should be saved. By default is current working directory.
      }
      def download(relative_source = ".", destination = ".")
        app = multiple_clouds(options[:cloud], "file download #{relative_source} #{destination}")
        app.download(relative_source, destination)
      rescue Client::ConflictException
        say_error "Cloud #{app} wasn't deployed properly. Cannot download files."
      end

      method_option :force, :type => :boolean, :aliases => "-f",
        :desc => "Skip confirmation question"
      desc "delete PATH", "Delete files from persistent data storage"
      def delete(path)
        app = multiple_clouds(options[:cloud], "file delete #{path}")

        unless options[:force]
          question = "Do you want to permanently delete #{path} (yes/no):"
          exit 1 unless yes?(question)
        end

        app.delete_file(path)
      rescue Client::ConflictException
        say_error "Cloud #{app} wasn't deployed properly. Cannot delete files."
      end

      no_tasks do
        def require_rsync
          unless command_exists?("rsync")
            say_error "You need to install rsync in order to upload and download files"
          end
        end
      end
    end
  end
end
