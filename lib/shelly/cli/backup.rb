require "shelly/cli/command"

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
        unless backups.empty?
          backups.unshift({"filename" => "Filename", "size" => "Size"})
          say "Available backups:", :green
          say_new_line
          print_table(backups.map do |backup|
            [backup['filename'], "|  #{backup['size']}"]
          end, :ident => 2)
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
    end
  end
end
