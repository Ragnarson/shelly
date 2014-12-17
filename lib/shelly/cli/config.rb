require "shelly/cli/command"

module Shelly
  module CLI
    class Config < Command
      namespace :config
      include Helpers

      before_hook :logged_in?, :only => [:list, :show, :create, :new, :add, :edit,
        :update, :upload, :delete]
      class_option :cloud, :type => :string, :aliases => "-c",
        :desc => "Specify cloud"

      desc "list", "List configuration files"
      def list
        app = multiple_clouds(options[:cloud], "config list")
        configs = app.configs
        unless configs.empty?
          say "Configuration files for #{app}", :green
          user_configs = app.user_configs
          unless user_configs.empty?
            say "Custom configuration files:"
            print_configs(user_configs)
          else
            say "You have no custom configuration files."
          end
          shelly_configs = app.shelly_generated_configs
          unless shelly_configs.empty?
            say "Following files are created by Shelly Cloud:"
            print_configs(shelly_configs)
          end
        else
          say "Cloud #{app} has no configuration files"
        end
      end

      desc "show PATH", "View configuration file"
      def show(path)
        app = multiple_clouds(options[:cloud], "config show #{path}")
        config = app.config(path)
        say "Content of #{config["path"]}:", :green
        say config["content"]
      rescue Client::NotFoundException => e
        raise unless e.resource == :config
        say_error "Config '#{path}' not found", :with_exit => false
        say_error "You can list available config files with `shelly config list --cloud #{app}`"
      end

      map "add" => :create
      map "new" => :create
      desc "create PATH", "Create configuration file"
      def create(path)
        app = multiple_clouds(options[:cloud], "create #{path}")
        if app.config_exists?(path)
          say "File '#{path}' already exists. Use `shelly config edit #{path} --cloud #{app}` to update it.", :red
        else
          output = open_editor(path)
          app.create_config(path, output)
          say "File '#{path}' created.", :green
          next_action_info(app)
        end
      rescue Client::ValidationException => e
        e.each_error { |error| say_error error, :with_exit => false }
        exit 1
      end

      map "update" => :edit
      desc "edit PATH", "Edit configuration file"
      def edit(path = nil)
        say_error "No configuration file specified" unless path
        app = multiple_clouds(options[:cloud], "config edit #{path}")
        config = app.config(path)
        content = open_editor(config["path"], config["content"])
        app.update_config(path, content)
        say "File '#{config["path"]}' updated.", :green
        next_action_info(app)
      rescue Client::NotFoundException => e
        raise unless e.resource == :config
        say_error "Config '#{path}' not found", :with_exit => false
        say_error "You can list available config files with `shelly config list --cloud #{app}`"
      rescue Client::ValidationException => e
        e.each_error { |error| say_error error, :with_exit => false }
        exit 1
      end

      desc "delete PATH", "Delete configuration file"
      def delete(path)
        app = multiple_clouds(options[:cloud], "config delete #{path}")
        if yes?("Are you sure you want to delete '#{path}' (yes/no):")
          app.delete_config(path)
          say "File '#{path}' deleted.", :green
          next_action_info(app)
        else
          say "File not deleted"
        end
      rescue Client::NotFoundException => e
        raise unless e.resource == :config
        say_error "Config '#{path}' not found", :with_exit => false
        say_error "You can list available config files with `shelly config list --cloud #{app}`"
      end

      desc "upload PATH [DESTINATION_PATH]", "Upload configuration file"
      long_desc %{
        Upload configuration file from local machine
        PATH - Path to configuration file that will be uploaded
        DESTINATION_PATH - Optional file path that file will be uploaded to. By default it's the same as PATH.
      }
      def upload(path, destination_path = nil)
        app = multiple_clouds(options[:cloud], "config upload #{path}")
        destination_path ||= path
        if ::File.exists?(path)
          content = ::File.read(path)
        else
          say_error "File '#{path}' doesn't exist."
        end
        if app.config_exists?(destination_path)
          if yes?("Config file '#{destination_path}' exists, do you want to overwrite it (yes/no):")
            app.update_config(destination_path, content)
            say "File '#{path}' uploaded.", :green
            next_action_info(app)
          else
            say "File not overwritten."
          end
        else
          app.create_config(destination_path, content)
          say "File '#{path}' uploaded.", :green
          next_action_info(app)
        end
      end

      no_tasks do
        def next_action_info(app)
          if app.turned_off?
            say "Changes will take affect when cloud is started"
            say "`shelly start --cloud #{app}`"
          else
            say "To make changes to running cloud redeploy it using:"
            say "`shelly redeploy --cloud #{app}`"
          end
        end

        def print_configs(configs)
          print_table(configs.map { |config|
            [" * ", config["path"]] })
        end

        def open_editor(path, output = "")
          filename = "shelly-edit-"
          0.upto(20) { filename += rand(9).to_s }
          filename << ::File.extname(path)
          filename = ::File.join(Dir.tmpdir, filename)
          tf = ::File.open(filename, "w")
          tf.sync = true
          tf.puts output
          tf.close
          no_editor unless system("#{ENV['EDITOR']} #{tf.path}")
          tf = ::File.open(filename, "r")
          output = tf.gets(nil)
          tf.close
          ::File.unlink(filename)
          output
        end

        def no_editor
          say_error "Please set EDITOR environment variable"
        end
      end
    end
  end
end
