require "shelly/cli/command"
require "shelly/backup"
require "shelly/download_progress_bar"
require 'launchy'

module Shelly
  module CLI
    class Backup < Command
      namespace :backup
      include Helpers

      before_hook :logged_in?, :only => [:list, :get, :create, :new, :restore, :import]

      class_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"

      method_option :all, :type => :boolean, :aliases => "-a",
        :desc => "Show all backups"
      desc "list", "List available database backups"
      def list
        app = multiple_clouds(options[:cloud], "backup list")
        backups = app.database_backups
        if backups.present?
          limit = 0
          unless options[:all] || backups.count < (Shelly::Backup::LIMIT + 1)
            limit = Shelly::Backup::LIMIT - 1
            say "Showing only last #{Shelly::Backup::LIMIT} backups.", :green
            say "Use --all or -a option to list all backups."
          end
          to_display = [["Filename", "|  Size", "|  State"]]
          backups[-limit..-1].each do |backup|
            to_display << [backup.filename, "|  #{backup.human_size}", "|  #{backup.state.humanize}"]
          end

          say_new_line
          print_table(to_display, :ident => 2)
        else
          say "No database backups available"
        end
      end

      map "download" => :get
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
        bar.finish

        say_new_line
        say "Backup file saved to #{backup.filename}", :green
      rescue Client::NotFoundException => e
        raise unless e.resource == :backup
        say_error "Backup not found", :with_exit => false
        say "You can list available backups with `shelly backup list` command"
      rescue Client::ForbiddenException => e
        say_error e[:message]
      end

      desc "create [DB_KIND]", "Create backup of given database"
      long_desc %{
        Create backup of given database.
        If database kind is not specified, Cloudfile must be present to backup all configured databases.
      }
      map "new" => :create
      def create(kind = nil)
        app = multiple_clouds(options[:cloud], "backup create [DB_KIND]")
        cloudfile = Cloudfile.new
        unless kind || cloudfile.present?
          say_error "Cloudfile must be present in current working directory " \
            "or specify database kind with:", :with_exit => false
          say_error "`shelly backup create DB_KIND`"
        end
        app.request_backup(kind || app.backup_databases)
        say "Backup requested. It can take up to several minutes for " +
          "the backup process to finish.", :green
      rescue Client::ValidationException => e
        e.each_error { |error| say_error error, :with_exit => false }
        exit 1
      rescue Client::ConflictException => e
        say_error e[:message]
      end

      desc "restore FILENAME", "Restore database to state from given backup"
      def restore(filename)
        app = multiple_clouds(options[:cloud], "backup restore FILENAME")
        backup = app.database_backup(filename)
        say "You are about to restore #{backup.kind} database for cloud" \
          " #{backup.code_name} to state from #{backup.filename}"
        say_new_line
        ask_to_restore_database
        app.restore_backup(filename)
        say_new_line
        say "Restore has been scheduled. Wait a few minutes till database is restored.", :green
      rescue Client::NotFoundException => e
        raise unless e.resource == :backup
        say_error "Backup not found", :with_exit => false
        say "You can list available backups with `shelly backup list` command"
      rescue Client::ConflictException => e
        say_error e[:message]
      end

      desc "import KIND FILENAME", "Import database from dump file"
      long_desc %{
        Import database from local dump file to your cloud
        KIND - Database kind. Possible values are: postgresql or mongodb
        FILENAME - Database dump file or directory (mongodb)
      }
      method_option :reset, :type => :boolean, :aliases => "-r",
        :desc => "Reset database before importing from file"
      def import(kind, filename)
        app = multiple_clouds(options[:cloud], "backup import KIND FILENAME")
        unless ::File.exist?(filename)
          say_error "File #{filename} doesn't exist"
        end
        unless ['postgresql', 'mysql', 'mongodb'].include?(kind)
          say_error "Kind is invalid. You can import backup of: postgresql, " \
            "mysql, mongodb"
        end
        if options[:reset]
          say_warning "You are about to reset database #{kind} for cloud #{app}"
          say_warning "Next, database will be restored to state from file #{filename}"
          question = "I want to reset and import the database from dump (yes/no):"
          say_new_line
          yes?(question) ? app.reset_database(kind) : say_error("Canceled")
        else
          say_warning "You are about to import #{kind} database for cloud " \
            "#{app} to state from file #{filename}"
          question = "I want to import the database from dump (yes/no):"
          say_new_line
          say_error "Canceled" unless yes?(question)
        end
        archive = compress(filename)
        say "Uploading #{archive}", :green
        connection = app.upload_database(archive)
        say "Uploading done", :green
        say "Importing database", :green
        app.import_database(kind, archive, connection["server"])
      rescue Client::ConflictException => e
        say_error "Cloud #{app} wasn't deployed properly. Cannot import database."
      end

      no_tasks do
        def compress(filename)
          archive_name = "#{::File.basename(filename)}-#{Time.now.to_i}.tar.bz2"
          say "Running: tar -cjf #{archive_name} #{filename}", :green
          system("tar -cjf #{archive_name} #{filename}")
          archive_name
        end
      end
    end
  end
end
