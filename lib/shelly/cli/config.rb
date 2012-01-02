require "shelly/cli/command"

module Shelly
  module CLI
    class Config < Command
      include Thor::Actions
      include Helpers

      before_hook :logged_in?, :only => [:list, :show, :create, :edit, :delete]
      before_hook :cloudfile_present?, :only => [:list, :show, :create, :edit, :delete]

      desc "list", "List configuration files"
      def list
        cloudfile = Cloudfile.new
        cloudfile.clouds.each do |cloud|
          @app = App.new(cloud)
          begin
            configs = @app.configs
            unless configs.empty?
              say "Configuration files for #{cloud}", :green
              user_configs = @app.user_configs
              unless user_configs.empty?
                say "Custom configuration files:"
                print_configs(user_configs)
              else
                say "You have no custom configuration files."
              end
              shelly_configs = @app.shelly_generated_configs
              unless shelly_configs.empty?
                say "Following files are created by Shelly Cloud:"
                print_configs(shelly_configs)
              end
            else
              say "Cloud #{cloud} has no configuration files"
            end
          rescue Client::APIError => e
            if e.resource_not_found == :cloud
              say_error "You have no access to '#{@app}' cloud defined in Cloudfile"
            else
              raise e
            end
          end
        end
      end

      method_option :cloud, :type => :string, :aliases => "-c",
        :desc => "Specify which cloud to show configuration file for"
      desc "show PATH", "View configuration file"
      def show(path = nil)
        say_error "No configuration file specified" unless path
        multiple_clouds(options[:cloud], "show #{path}", "Specify cloud using:")
        config = @app.config(path)
        say "Content of #{config["path"]}:", :green
        say config["content"]
      rescue Client::APIError => e
        case e.resource_not_found
        when :cloud
          say_error "You have no access to '#{@app.code_name}' cloud defined in Cloudfile"
        when :config
          say_error "Config '#{path}' not found", :with_exit => false
          say_error "You can list available config files with `shelly config list --cloud #{@app}`"
        else; raise e
        end
      end

      map "new" => :create
      method_option :cloud, :type => :string, :aliases => "-c",
        :desc => "Specify which cloud to create configuration file for"
      desc "create PATH", "Create configuration file"
      def create(path = nil)
        say_error "No path specified" unless path
        output = open_editor(path)
        multiple_clouds(options[:cloud], "create #{path}", "Specify cloud using:")
        @app.create_config(path, output)
        say "File '#{path}' created, it will be used after next code deploy", :green
      rescue Client::APIError => e
        if e.resource_not_found == :cloud
          say_error "You have no access to '#{@app.code_name}' cloud defined in Cloudfile"
        elsif e.validation?
          e.each_error { |error| say_error error, :with_exit => false }
          exit 1
        else
          say_error e.message
        end
      end

      map "update" => :edit
      method_option :cloud, :type => :string, :aliases => "-c",
        :desc => "Specify which cloud to edit configuration file for"
      desc "edit PATH", "Edit configuration file"
      def edit(path = nil)
        say_error "No configuration file specified" unless path
        multiple_clouds(options[:cloud], "edit #{path}", "Specify cloud using:")
        config = @app.config(path)
        content = open_editor(config["path"], config["content"])
        @app.update_config(path, content)
        say "File '#{config["path"]}' updated, it will be used after next code deploy", :green
      rescue Client::APIError => e
        if e.resource_not_found == :cloud
          say_error "You have no access to '#{@app.code_name}' cloud defined in Cloudfile"
        elsif e.resource_not_found == :config
          say_error "Config '#{path}' not found", :with_exit => false
          say_error "You can list available config files with `shelly config list --cloud #{@app}`"
        elsif e.validation?
          e.each_error { |error| say_error error, :with_exit => false }
          exit 1
        else
          say_error e.message
        end
      end

      method_option :cloud, :type => :string, :aliases => "-c",
        :desc => "Specify for which cloud to delete configuration file for"
      desc "delete PATH", "Delete configuration file"
      def delete(path = nil)
        say_error "No configuration file specified" unless path
        multiple_clouds(options[:cloud], "delete #{path}", "Specify cloud using:")
        answer = yes?("Are you sure you want to delete 'path' (yes/no): ")
        if answer
          @app.delete_config(path)
          say "File deleted, redeploy your cloud to make changes", :green
        else
          say "File not deleted"
        end
      rescue Client::APIError => e
        if e.resource_not_found == :cloud
          say_error "You have no access to '#{@app.code_name}' cloud defined in Cloudfile"
        elsif e.resource_not_found == :config
          say_error "Config '#{path}' not found", :with_exit => false
          say_error "You can list available config files with `shelly config list --cloud #{@app}`"
        elsif e.validation?
          e.each_error { |error| say_error error, :with_exit => false }
          exit 1
        else
          say_error e.message
        end
      end

      no_tasks do
        def print_configs(configs)
          print_table(configs.map { |config|
            [" * ", config["path"]] })
        end

        def open_editor(path, output = "")
          filename = "shelly-edit-"
          0.upto(20) { filename += rand(9).to_s }
          filename << File.extname(path)
          filename = File.join(Dir.tmpdir, filename)
          tf = File.open(filename, "w")
          tf.sync = true
          tf.puts output
          tf.close
          no_editor unless system("#{ENV['EDITOR']} #{tf.path}")
          tf = File.open(filename, "r")
          output = tf.gets(nil)
          tf.close
          File.unlink(filename)
          output
        end

        def no_editor
          say_error "Please set EDITOR environment variable"
        end
      end

    end
  end
end