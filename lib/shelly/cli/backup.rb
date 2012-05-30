require "shelly/cli/command"
require "shelly/backup"
require "shelly/download_progress_bar"

module Shelly
  module CLI
    class Backup < Command
      namespace :backup
      include Helpers

      before_hook :logged_in?, :only => [:list, :get, :create, :restore]

      class_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"

      desc "list", "List available database backups"
      def list
        app = multiple_clouds(options[:cloud], "backup list")
        backups = app.database_backups
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
      rescue Client::NotFoundException => e
        raise unless e.resource == :cloud
        say_error "You have no access to '#{app}' cloud defined in Cloudfile"
      end

      desc "get [FILENAME]", "Download database backup"
      long_desc %{
        Download given database backup to current directory.
        If filename is not specyfied, latest database backup will be downloaded.
      }
      def get(handler = "last")
        app = multiple_clouds(options[:cloud], "backup get #{handler}")

        backup = app.database_backup(handler)
        bar = Shelly::DownloadProgressBar.new(backup.size)
        backup.download(bar.progress_callback)

        say_new_line
        say "Backup file saved to #{backup.filename}", :green
      rescue Client::NotFoundException => e
        case e.resource
        when :cloud
          say_error "You have no access to '#{app}' cloud defined in Cloudfile"
        when :database_backup
          say_error "Backup not found", :with_exit => false
          say "You can list available backups with `shelly backup list` command"
        else; raise
        end
      end

      desc "create [DB_KIND]", "Create backup of given database"
      long_desc %{
        Create backup of given database.
        If database kind is not specified, backup of all configured databases will be performed.
      }
      def create(kind = nil)
        app = multiple_clouds(options[:cloud], "backup create [DB_KIND]")
        app.request_backup(kind)
        say "Backup requested. It can take up to several minutes for " +
          "the backup process to finish and the backup to show up in backups list.", :green
      rescue Client::ValidationException => e
        say_error e[:message]
      rescue Client::NotFoundException => e
        raise unless e.resource == :cloud
        say_error "You have no access to '#{app}' cloud defined in Cloudfile"
      end

      desc "restore FILENAME", "Restore database to state from given backup"
      def restore(filename)
        app = multiple_clouds(options[:cloud], "backup restore FILENAME")
        backup = app.database_backup(filename)
        say "You are about restore database #{backup.kind} for cloud #{backup.code_name} to state from #{backup.filename}"
        say_new_line
        ask_to_restore_database
        app.restore_backup(filename)
        say_new_line
        say "Restore has been scheduled. Wait a few minutes till database is restored.", :green
      rescue Client::NotFoundException => e
        case e.resource
        when :cloud
          say_error "You have no access to '#{app}' cloud defined in Cloudfile"
        when :database_backup
          say_error "Backup not found", :with_exit => false
          say "You can list available backups with `shelly backup list` command"
        else; raise
        end
      end
    end
  end
end
