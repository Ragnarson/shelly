require "shelly/cli/command"
require "shelly/backup"
require "shelly/download_progress_bar"

module Shelly
  module CLI
    class Backup < Command
      namespace :backup
      include Helpers

      desc "list", "List database backup clouds defined in Cloudfile"
      def list(cloud = nil)
        logged_in?
        say_error "Must be run inside your project git repository" unless App.inside_git_repository?
        say_error "No Cloudfile found" unless Cloudfile.present?
        multiple_clouds(cloud, "backup list", "Select cloud to view database backups using:")
        backups = @app.database_backups
        if backups.present?
          to_display = [["Filename", "|  Size"]]
          backups.each do |backup|
            to_display << [backup.filename, "|  #{backup.human_size}"]
          end

          say "Available backups:", :green
          say_new_line
          print_table(to_display, :ident => 2)
        else
          say "No database backups available"
        end
      rescue Client::APIError => e
        if e.unauthorized?
          say_error "You have no access to '#{@app.code_name}' cloud defined in Cloudfile"
        else
          say_error e.message
        end
      end

      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify which cloud list backups for"
      desc "get [FILENAME]", "Downloads specified or last backup to current directory"
      def get(handler = "last")
        multiple_clouds(options[:cloud], "backup get [FILENAME]", "Select cloud for which you want download backup")

        backup = @app.database_backup(handler)
        bar = Shelly::DownloadProgressBar.new(backup.size)
        backup.download(bar.progress_callback)

        say_new_line
        say "Backup file saved to #{backup.filename}", :green
      rescue Client::APIError => e
        if e.not_found?
          say_error "Backup not found", :with_exit => false
          say "You can list available backups with 'shelly backup list' command"
        else
          raise e
        end
      end
    end
  end
end
