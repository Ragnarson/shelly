require "shelly/cli/command"
require "shelly/cli/user"
require "shelly/cli/backup"
require "shelly/cli/deploy"
require "shelly/cli/database"
require "shelly/cli/config"
require "shelly/cli/file"
require "shelly/cli/organization"
require "shelly/cli/logs"
require "shelly/cli/endpoint"
require "shelly/cli/maintenance"

require "shelly/cli/main/add"
require "shelly/cli/main/check"

require "io/console"

module Shelly
  module CLI
    class Main < Command
      register_subcommand(User, "user", "user <command>", "Manage collaborators")
      register_subcommand(Backup, "backup", "backup <command>", "Manage database backups")
      register_subcommand(Database, "database", "database <command>", "Manage databases")
      register_subcommand(Deploy, "deploy", "deploy <command>", "View deploy logs")
      register_subcommand(Config, "config", "config <command>", "Manage application configuration files")
      register_subcommand(File, "file", "file <command>", "Upload and download files to and from persistent storage")
      register_subcommand(Organization, "organization", "organization <command>", "View organizations")
      register_subcommand(Logs, "log", "logs <command>", "View application logs")
      register_subcommand(Endpoint, "endpoint", "cert <command>", "Mange application HTTP(S) endpoints")
      register_subcommand(Maintenance, "maintenance", "maintenance <command>", "Mange application maintenance events")

      check_unknown_options!(:except => :rake)

      # FIXME: it should be possible to pass single symbol, instead of one element array
      before_hook :logged_in?, :only => [:add, :status, :list, :start, :stop,
        :delete, :info, :ip, :logout, :execute, :rake, :setup, :console,
        :dbconsole, :mongoconsole, :redis_cli, :ssh]
      before_hook :inside_git_repository?, :only => [:add, :setup, :check]

      map %w(-v --version) => :version
      desc "version", "Display shelly version"
      def version
        say "shelly version #{Shelly::VERSION}"
      end

      desc "register [EMAIL]", "Register new account"
      def register(email = nil)
        say "Registering with email: #{email}" if email
        user = Shelly::User.new
        email ||= ask_for_email
        password = ask_for_password
        ask_for_acceptance_of_terms
        user.register(email, password)
        say "Successfully registered!", :green
      rescue Client::ValidationException => e
        e.each_error { |error| say_error "#{error}", :with_exit => false }
        exit 1
      end

      desc "login [EMAIL]", "Log into Shelly Cloud"
      method_option :key, :alias => :k, :desc => "Path to specific SSH key", :default => nil
      def login(email = nil)
        user = Shelly::User.new

        if options[:key]
          given_key = Shelly::SshKey.new(options[:key])
          say "Your given SSH key (#{given_key.path}) will be uploaded to Shelly Cloud after login."
          raise Errno::ENOENT, given_key.path unless given_key.exists?
        else
          say "Your public SSH key will be uploaded to Shelly Cloud after login."
          raise Errno::ENOENT, user.ssh_key.path unless user.ssh_key.exists?
        end
        email ||= ask_for_email
        password = ask_for_password(:with_confirmation => false)
        user.login(email, password)
        upload_ssh_key(options[:key])
        say "Login successful", :green
        list
      rescue Client::ValidationException => e
        e.each_error { |error| say_error "#{error}", :with_exit => false }
      rescue Client::UnauthorizedException => e
        say_error e[:error], :with_exit => false
        if e[:url]
          say_error "You can reset password by using link:", :with_exit => false
          say_error e[:url]
        end
        exit 1
      rescue Errno::ENOENT => e
        say_error e, :with_exit => false
        say_error "Use ssh-keygen to generate ssh key pair"
      end

      map "status" => :list
      desc "list", "List available clouds"
      def list
        user = Shelly::User.new
        apps = user.apps
        unless apps.empty?
          say "You have following clouds available:", :green
          print_table(apps_table(apps), :ident => 2)
        else
          say "You have no clouds yet", :green
        end
      end

      map "ip" => :info
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      desc "info", "Show basic information about cloud"
      def info
        app = multiple_clouds(options[:cloud], "info")
        msg = info_show_last_deploy_logs(app)
        say "Cloud #{app}:", app.in_deploy_failed_state? ? :red : :green
        print_wrapped "Region: #{app.region}", :ident => 2
        print_wrapped "State: #{app.state_description}#{msg}", :ident => 2
        say_new_line
        print_wrapped "Deployed commit sha: #{app.git_info["deployed_commit_sha"]}", :ident => 2
        print_wrapped "Deployed commit message: #{app.git_info["deployed_commit_message"]}", :ident => 2
        print_wrapped "Deployed by: #{app.git_info["deployed_push_author"]}", :ident => 2
        say_new_line
        print_wrapped "Repository URL: #{app.git_info["repository_url"]}", :ident => 2
        print_wrapped "Web server IP: #{app.web_server_ip.join(', ')}", :ident => 2
        say_new_line

        print_wrapped "Usage:", :ident => 2
        app.usage.each do |usage|
          print_wrapped "#{usage['kind'].capitalize}:", :ident => 4
          print_wrapped "Current: #{number_to_human_size(usage['current'])}", :ident => 6
          print_wrapped "Average: #{number_to_human_size(usage['avg'])}", :ident => 6
        end

        print_wrapped "Traffic:", :ident => 4
        print_wrapped "Incoming: #{number_to_human_size(app.traffic['incoming'].to_i)}", :ident => 6
        print_wrapped "Outgoing: #{number_to_human_size(app.traffic['outgoing'].to_i)}", :ident => 6
        print_wrapped "Total: #{number_to_human_size(app.traffic['total'].to_i)}", :ident => 6

        say_new_line
        if app.statistics.present?
          print_wrapped "Statistics:", :ident => 2
          app.statistics.each do |stat|
            print_wrapped "#{stat['name']}:", :ident => 4
            print_wrapped "Load average: 1m: #{stat['load']['avg01']}, 5m: #{stat['load']['avg05']}, 15m: #{stat['load']['avg15']}", :ident => 6
            print_wrapped "CPU: #{stat['cpu']['wait']}%, MEM: #{stat['memory']['percent']}%, SWAP: #{stat['swap']['percent']}%", :ident => 6
          end
        end
      rescue Client::GatewayTimeoutException
        say_error "Server statistics temporarily unavailable"
      end

      desc "start", "Start the cloud"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def start
        app = multiple_clouds(options[:cloud], "start")
        deployment_id = app.start
        say "Starting cloud #{app}.", :green
        say_new_line
        deployment_progress(app, deployment_id, "Starting cloud")
      rescue Client::ConflictException => e
        case e[:state]
        when "running"
          say_error "Not starting: cloud '#{app}' is already running"
        when "deploying"
          say_error "Not starting: cloud '#{app}' is currently deploying"
        when "no_code"
          say_error "Not starting: no source code provided", :with_exit => false
          say_error "Push source code using:", :with_exit => false
          say       "`git push #{app.git_remote_name} master`"
        when "deploy_failed"
          say_error "Not starting: deployment failed", :with_exit => false
          say_error "Support has been notified", :with_exit => false
          say_error "Check `shelly deploys show last --cloud #{app}` for reasons of failure"
        when "not_enough_resources"
          say_error %{Sorry, There are no resources for your servers.
We have been notified about it. We will be adding new resources shortly}
        when "no_billing"
          say_error "Please fill in billing details to start #{app}.", :with_exit => false
          say_error "Visit: #{app.edit_billing_url}", :with_exit => false
        when "turning_off"
          say_error %{Not starting: cloud '#{app}' is turning off.
Wait until cloud is in 'turned off' state and try again.}
        end
        exit 1
      rescue Client::LockedException => e
        say_error "Deployment is currently blocked:", :with_exit => false
        say_error e[:message]
        exit 1
      end

      desc "setup", "Set up git remotes for deployment on Shelly Cloud"
      long_desc %{
        Set up git remotes for deployment on Shelly Cloud.

        When an application is cloned from a git repository (for example from Github)
        shelly setup will set up git remotes needed for deployment on Shelly Cloud.

        Application must have Cloudfile in the repository.
      }
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def setup
        app = multiple_clouds(options[:cloud], "setup")
        say "Setting up #{app} cloud", :green
        say_new_line
        app.git_url = app.attributes["git_info"]["repository_url"]
        if overwrite_default_remote?(app)
          say "Running: git remote add shelly #{app.git_url}"
          app.add_git_remote
          say "Running: git fetch shelly"
          app.git_fetch_remote
        else
          loop do
            remote = ask('Specify remote name:')
            if app.git_remote_exist?(remote)
              say("Remote '#{remote}' already exists")
            else
              say "Running: git remote add #{remote} #{app.git_url}"
              app.add_git_remote(remote)
              say "Running: git fetch #{remote}"
              app.git_fetch_remote(remote)
              break
            end
          end
        end

        say_new_line
        say "Your application is set up.", :green
      end

      desc "stop", "Shutdown the cloud"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def stop
        app = multiple_clouds(options[:cloud], "stop")
        if yes?("Are you sure you want to shut down '#{app}' cloud (yes/no):")
          deployment_id = app.stop
          say_new_line
          deployment_progress(app, deployment_id, "Stopping cloud")
        end
      rescue Client::ConflictException => e
        case e[:state]
        when "deploying"
          say_error "Your cloud is currently being deployed and it can not be stopped."
        when "no_code"
          say_error "You need to deploy your cloud first.", :with_exit => false
          say       "More information can be found at:"
          say       "#{app.shelly.shellyapp_url}/documentation/deployment"
          exit 1
        when "turning_off"
          say_error "Your cloud is turning off."
        end
      rescue Client::NotFoundException => e
        raise unless e.resource == :cloud
        say_error "You have no access to '#{app}' cloud defined in Cloudfile"
      end

      desc "delete", "Delete the cloud"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def delete
        app = multiple_clouds(options[:cloud], "delete")

        say_new_line
        say "You are going to:"
        say " * remove all files stored in the persistent storage for #{app},"
        say " * remove all database data for #{app},"
        say " * remove #{app} cloud from Shelly Cloud"
        say_new_line
        say "This action is permanent and can not be undone.", :red
        say_new_line
        ask_to_delete_application app
        # load git info so remote can be removed later on
        app.git_info

        app.delete

        say_new_line
        say "Scheduling application delete - done"
        if App.inside_git_repository?
          app.remove_git_remote
          say "Removing git remote - done"
        else
          say "Missing git remote"
        end
      rescue Client::ConflictException => e
        say_error e[:message]
      end

      desc "logout", "Logout from Shelly Cloud"
      method_option :key, :alias => :k, :desc => "Path to specific SSH key",
        :default => nil
      def logout
        user = Shelly::User.new
        key = Shelly::SshKey.new(options[:key]) if options[:key]
        if (key || user.ssh_keys).destroy
          say "Your public SSH key has been removed from Shelly Cloud"
        end

        say "You have been successfully logged out" if user.logout
      end

      desc "rake TASK", "Run rake task"
      method_option :cloud, :type => :string, :aliases => "-c",
        :desc => "Specify cloud"
      method_option :server, :type => :string, :aliases => "-s",
        :desc => "Specify virtual server, it's random by default"
      def rake(task = nil)
        task = rake_args.join(" ")
        app = multiple_clouds(options[:cloud], "rake #{task}")
        app.rake(task, options[:server])
      rescue Client::ConflictException
        say_error "Cloud #{app} is not running. Cannot run rake task."
      rescue Client::NotFoundException => e
        raise unless e.resource == :virtual_server
        say_error "Virtual server '#{options[:server]}' not found or" \
          " not configured for running rake task."
      end

      desc "dbconsole", "Run rails dbconsole"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def dbconsole(task = nil)
        app = multiple_clouds(options[:cloud], "dbconsole")
        app.dbconsole
      rescue Client::ConflictException
        say_error "Cloud #{app} wasn't deployed properly. Can not run dbconsole."
      end

      desc "mongoconsole", "Run MongoDB console"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def mongoconsole
        app = multiple_clouds(options[:cloud], "mongoconsole")
        app.mongoconsole
      rescue Client::ConflictException
        say_error "Cloud #{app} wasn't deployed properly. Can not run MongoDB console."
      end

      desc "redis-cli", "Run redis-cli"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def redis_cli
        app = multiple_clouds(options[:cloud], "redis-cli")
        app.redis_cli
      rescue Client::ConflictException
        say_error "Cloud #{app} wasn't deployed properly. Can not run redis-cli."
      end

      desc "redeploy", "Redeploy application"
      method_option :cloud, :type => :string, :aliases => "-c",
        :desc => "Specify which cloud to redeploy application for"
      def redeploy
        app = multiple_clouds(options[:cloud], "redeploy")
        deployment_id = app.redeploy
        say "Redeploying your application for cloud '#{app}'", :green
        deployment_progress(app, deployment_id, "Cloud redeploy")
      rescue Client::ConflictException => e
        case e[:state]
        when "deploying"
          say_error "Your application is being redeployed at the moment"
        when "no_code", "no_billing", "turned_off"
          say_error "Cloud #{app} is not running", :with_exit => false
          say "Start your cloud with `shelly start --cloud #{app}`"
          exit 1
        else raise
        end
      rescue Client::LockedException => e
        say_error "Deployment is currently blocked:", :with_exit => false
        say_error e[:message]
        exit 1
      end

      desc "open", "Open application page in browser"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def open
        app = multiple_clouds(options[:cloud], "open")
        app.open
      end

      desc "console", "Open application console"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      method_option :server, :type => :string, :aliases => "-s",
        :desc => "Specify virtual server, it's random by default"
      def console
        app = multiple_clouds(options[:cloud], "console")
        app.console(options[:server])
      rescue Client::ConflictException
        say_error "Cloud #{app} is not running. Cannot run console."
      rescue Client::NotFoundException => e
        raise unless e.resource == :virtual_server
        say_error "Virtual server '#{options[:server]}' not found or not configured for running console"
      end

      desc "ssh", "Log into virtual server"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      method_option :server, :type => :string, :aliases => "-s",
        :desc => "Specify virtual server, it's random by default"
      def ssh
        app = multiple_clouds(options[:cloud], "ssh")
        app.ssh_console(options[:server])
      rescue Client::ConflictException
        say_error "Cloud #{app} is not running. Cannot run ssh console."
      rescue Client::NotFoundException => e
        raise unless e.resource == :virtual_server
        say_error "Virtual server '#{options[:server]}' not found or not configured for running ssh console"
      end

      # FIXME: move to helpers
      no_tasks do
        # Returns valid arguments for rake, removes shelly gem arguments
        def rake_args(args = ARGV)
          skip_next = false
          [].tap do |out|
            args.each do |arg|
              case arg
              when "rake", "--debug"
              when "--cloud", "-c", "--server", "-s"
                skip_next = true
              else
                out << arg unless skip_next
                skip_next = false
              end
            end
          end
        end

        def check_options(options)
          unless options.empty?
            if !valid_size?(options["size"]) or !valid_databases?(options["databases"])
              say_error "Try `shelly help add` for more information"
            end
          end
        end

        def valid_size?(size)
          return true unless size.present?
          sizes = Shelly::App::SERVER_SIZES
          sizes.include?(size)
        end

        def valid_databases?(databases)
          return true unless databases.present?
          kinds = Shelly::App::DATABASE_CHOICES
          databases.all? { |kind| kinds.include?(kind) }
        end

        def overwrite_default_remote?(app)
          git_remote = app.git_remote_exist?
          !git_remote or (git_remote and yes?("Git remote shelly exists, overwrite (yes/no): "))
        end

        def add_remote(app)
          remote = if overwrite_default_remote?(app)
            say "Running: git remote add shelly #{app.git_url}", :green
            "shelly"
          else
            loop do
              remote = ask('Specify remote name:')
              if app.git_remote_exist?(remote)
                say("Remote '#{remote}' already exists")
              else
                say "Running: git remote add #{remote} #{app.git_url}", :green
                break remote
              end
            end
          end

          app.add_git_remote(remote)
          remote
        end

        def ask_for_password(options = {})
          options = {:with_confirmation => true}.merge(options)
          loop do
            say "Password: "
            password = capture_input_without_echo_if_tty
            say_new_line
            return password unless options[:with_confirmation]
            say "Password confirmation: "
            password_confirmation = capture_input_without_echo_if_tty
            say_new_line
            if password.present?
              return password if password == password_confirmation
              say_error "Password and password confirmation don't match, please type them again"
            else
              say_error "Password can't be blank"
            end
          end
        end

        def ask_for_code_name
          default_code_name = default_name_from_dir_name
          code_name = ask("Cloud code name (#{default_code_name} - default):")
          code_name.blank? ? default_code_name : code_name
        end

        def ask_for_databases
          kinds = Shelly::App::DATABASE_CHOICES
          databases = ask("Which databases do you want to use " \
                          "#{kinds.join(", ")} (postgresql - default):")
          begin
            databases = databases.split(/[\s,]/).reject(&:blank?)
            valid = valid_databases?(databases)
            break if valid
            databases = ask("Unknown database kind. Supported are: #{kinds.join(", ")}:")
          end while not valid

          databases.empty? ? ["postgresql"] : databases
        end

        def info_adding_cloudfile_to_repository
          say_new_line
          say "Project is now configured for use with Shelly Cloud:", :green
          say "You can review changes using", :green
          say "  git status"
        end

        def info_deploying_to_shellycloud(remote = 'shelly')
          say_new_line
          say "When you make sure all settings are correct, add changes to your repository:", :green
          say "  git add ."
          say '  git commit -m "Application added to Shelly Cloud"'
          say_new_line
          say "Deploy to your cloud using:", :green
          say "  git push #{remote} master"
          say_new_line
        end

        def upload_ssh_key(given_key_path = nil)
          user = Shelly::User.new
          ssh_key = given_key_path ? Shelly::SshKey.new(given_key_path) : user.ssh_key

          if ssh_key.exists?
            if ssh_key.uploaded?
              say "Your SSH key from #{ssh_key.path} is already uploaded"
            else
              say "Uploading your public SSH key from #{ssh_key.path}"
              ssh_key.upload
            end
          else
            say_error "No such file or directory - #{ssh_key_path}", :with_exit => false
            say_error "Use ssh-keygen to generate ssh key pair, after that use: `shelly login`", :with_exit => false
          end
        rescue Client::ValidationException => e
          e.each_error { |error| say_error error, :with_exit => false }
          user.logout
          exit 1
        end

        def capture_input_without_echo_if_tty
          $stdin.tty? ? $stdin.noecho(&:gets).strip : $stdin.gets.strip
        end
      end
    end
  end
end
