# encoding: utf-8
require "shelly/cli/command"
require "shelly/cli/user"
require "shelly/cli/backup"
require "shelly/cli/deploy"
require "shelly/cli/config"
require "shelly/cli/file"
require "shelly/cli/organization"

module Shelly
  module CLI
    class Main < Command
      register_subcommand(User, "user", "user <command>", "Manage collaborators")
      register_subcommand(Backup, "backup", "backup <command>", "Manage database backups")
      register_subcommand(Deploy, "deploy", "deploy <command>", "View deploy logs")
      register_subcommand(Config, "config", "config <command>", "Manage application configuration files")
      register_subcommand(File, "file", "file <command>", "Upload and download files to and from persistent storage")
      register_subcommand(Organization, "organization", "organization <command>", "View organizations")

      check_unknown_options!(:except => :rake)

      # FIXME: it should be possible to pass single symbol, instead of one element array
      before_hook :logged_in?, :only => [:add, :status, :list, :start, :stop, :logs, :delete, :info, :ip, :logout, :execute, :rake, :setup, :console, :dbconsole]
      before_hook :inside_git_repository?, :only => [:add, :setup, :check]

      map %w(-v --version) => :version
      desc "version", "Display shelly version"
      def version
        say "shelly version #{Shelly::VERSION}"
      end

      desc "register [EMAIL]", "Register new account"
      def register(email = nil)
        user = Shelly::User.new
        say "Your public SSH key will be uploaded to Shelly Cloud after registration."
        say "Registering with email: #{email}" if email
        user.email = (email || ask_for_email)
        user.password = ask_for_password
        ask_for_acceptance_of_terms
        user.register
        if user.ssh_key_exists?
          say "Uploading your public SSH key from #{user.ssh_key_path}"
        else
          say_error "No such file or directory - #{user.ssh_key_path}", :with_exit => false
          say_error "Use ssh-keygen to generate ssh key pair, after that use: `shelly login`", :with_exit => false
        end
        say "Successfully registered!", :green
        say "Check you mailbox for email address confirmation", :green
      rescue Client::ValidationException => e
        e.each_error { |error| say_error "#{error}", :with_exit => false }
        exit 1
      end

      desc "login [EMAIL]", "Log into Shelly Cloud"
      def login(email = nil)
        user = Shelly::User.new
        say "Your public SSH key will be uploaded to Shelly Cloud after login."
        raise Errno::ENOENT, user.ssh_key_path unless user.ssh_key_exists?
        user.email = email || ask_for_email
        user.password = ask_for_password(:with_confirmation => false)
        user.login
        say "Login successful", :green
        user.upload_ssh_key
        say "Uploading your public SSH key"
        list
      rescue Client::ValidationException => e
        e.each_error { |error| say_error "#{error}", :with_exit => false }
      rescue Client::UnauthorizedException => e
        say_error "Wrong email or password", :with_exit => false
        say_error "You can reset password by using link:", :with_exit => false
        say_error e[:url]
      rescue Errno::ENOENT => e
        say_error e, :with_exit => false
        say_error "Use ssh-keygen to generate ssh key pair"
      end

      method_option "code-name", :type => :string, :aliases => "-c",
        :desc => "Unique code-name of your cloud"
      method_option :databases, :type => :array, :aliases => "-d",
        :banner => Shelly::App::DATABASE_CHOICES.join(', '),
        :desc => "List of databases of your choice"
      method_option :size, :type => :string, :aliases => "-s",
        :desc => "Server size [large, small]"
      method_option "redeem-code", :type => :string, :aliases => "-r",
        :desc => "Redeem code for free credits"
      method_option "organization", :type => :string, :aliases => "-o",
        :desc => "Add cloud to existing organization"
      method_option "skip-requirements-check", :type => :boolean,
        :desc => "Skip Shelly Cloud requirements check"
      method_option "default-organization", :type => :boolean,
        :desc => "Create cloud with default organization"
      method_option "zone", :type => :string, :hide => true,
        :desc => "Create cloud in given zone"
      desc "add", "Add a new cloud"
      def add
        check_options(options)
        unless options["skip-requirements-check"]
          return unless check(verbose = false)
        end
        app = Shelly::App.new
        app.code_name = options["code-name"] || ask_for_code_name
        app.databases = options["databases"] || ask_for_databases
        app.size = options["size"] || "large"
        app.redeem_code = options["redeem-code"]
        unless options["default-organization"]
          app.organization = options["organization"] || ask_for_organization(app.code_name)
        end
        app.zone_name = options["zone"]
        app.create

        if overwrite_remote?(app)
          say "Adding remote #{app} #{app.git_url}", :green
          app.add_git_remote
        else
          say "You have to manually add git remote:"
          say "`git remote add NAME #{app.git_url}`"
        end

        say "Creating Cloudfile", :green
        app.create_cloudfile
        if app.credit > 0 || !app.organization_details_present?
          say_new_line
          say "Billing information", :green
          if app.credit > 0
            say "#{app.credit.to_i} Euro credit remaining."
          end
          if !app.organization_details_present?
            say "Remember to provide billing details before trial ends."
            say app.edit_billing_url
          end
        end

        info_adding_cloudfile_to_repository
        info_deploying_to_shellycloud(app)

      rescue Client::ValidationException => e
        e.each_error { |error| say_error error, :with_exit => false }
        say_new_line
        say_error "Fix erros in the below command and type it again to create your cloud" , :with_exit => false
        say_error "shelly add --code-name=#{app.code_name.downcase.dasherize} --databases=#{app.databases.join(',')} --size=#{app.size}"
      rescue Client::ForbiddenException
        say_error "You have to be the owner of '#{options[:organization]}' organization to add clouds"
      rescue Client::NotFoundException => e
        raise unless e.resource == :organization
        say_error "Organization '#{app.organization}' not found", :with_exit => false
        say_error "You can list organizations you have access to with `shelly organization list`"
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
        msg = if app.state == "deploy_failed" || app.state == "configuration_failed"
          " (deployment log: `shelly deploys show last -c #{app}`)"
        end
        say "Cloud #{app}:", msg.present? ? :red : :green
        print_wrapped "State: #{app.state_description}#{msg}", :ident => 2
        say_new_line
        print_wrapped "Deployed commit sha: #{app.git_info["deployed_commit_sha"]}", :ident => 2
        print_wrapped "Deployed commit message: #{app.git_info["deployed_commit_message"]}", :ident => 2
        print_wrapped "Deployed by: #{app.git_info["deployed_push_author"]}", :ident => 2
        say_new_line
        print_wrapped "Repository URL: #{app.git_info["repository_url"]}", :ident => 2
        print_wrapped "Web server IP: #{app.web_server_ip}", :ident => 2
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
          say       "`git push #{app} master`"
        when "deploy_failed", "configuration_failed"
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
        app.git_url = app.attributes["git_info"]["repository_url"]
        if overwrite_remote?(app)
          say "git remote add #{app} #{app.git_url}"
          app.add_git_remote
          say "git fetch #{app}"
          app.git_fetch_remote
          say "git checkout -b #{app} --track #{app}/master"
          app.git_add_tracking_branch
        else
          say "You have to manually add remote:"
          say "`git remote add #{app} #{app.git_url}`"
          say "`git fetch production`"
          say "`git checkout -b #{app} --track #{app}/master`"
        end

        say_new_line
        say "Your application is set up.", :green
      end

      desc "stop", "Shutdown the cloud"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def stop
        app = multiple_clouds(options[:cloud], "stop")
        stop_question = "Are you sure you want to shut down '#{app}' cloud (yes/no):"
        if ask(stop_question) == "yes"
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
        say "You are about to delete application: #{app}."
        say "Press Control-C at any moment to cancel."
        say "Please confirm each question by typing yes and pressing Enter."
        say_new_line
        ask_to_delete_files
        ask_to_delete_database
        ask_to_delete_application
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

      desc "logs", "Show latest application logs"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      method_option :limit, :type => :numeric, :aliases => "-n", :desc => "Amount of messages to show"
      method_option :from, :type => :string, :desc => "Time from which to find the logs"
      method_option :source, :type => :string, :aliases => "-s", :desc => "Limit logs to a single source, e.g. nginx"
      method_option :tail, :type => :boolean, :aliases => "-f", :desc => "Show new logs automatically"
      def logs
        cloud = options[:cloud]
        app = multiple_clouds(cloud, "logs")
        limit = options[:limit].to_i <= 0 ? 100 : options[:limit]
        query = {:limit => limit, :source => options[:source]}
        query.merge!(:from => options[:from]) if options[:from]

        logs = app.application_logs(query)
        print_logs(logs)

        if options[:tail]
          app.application_logs_tail { |logs| print logs }
        end

      rescue Client::APIException => e
        raise e unless e.status_code == 416
        say_error "You have requested too many log messages. Try a lower number."
      end

      desc "logout", "Logout from Shelly Cloud"
      def logout
        user = Shelly::User.new
        say "Your public SSH key has been removed from Shelly Cloud" if user.delete_ssh_key
        say "You have been successfully logged out" if user.delete_credentials
      end

      desc "rake TASK", "Run rake task"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def rake(task = nil)
        task = rake_args.join(" ")
        app = multiple_clouds(options[:cloud], "rake #{task}")
        app.rake(task)
      rescue Client::ConflictException
        say_error "Cloud #{app} is not running. Cannot run rake task."
      end

      desc "dbconsole", "Run rails dbconsole"
      method_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"
      def dbconsole(task = nil)
        app = multiple_clouds(options[:cloud], "dbconsole")
        app.dbconsole
      rescue Client::ConflictException
        say_error "Cloud #{app} is not running. Cannot run dbconsole."
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
        say_error "Virtual Server '#{options[:server]}' not found"
      end

      desc "check", "Check if application fulfills Shelly Cloud requirements"
      # Public: Check if application fulfills shelly's requirements
      #         and print them
      # verbose - when true all requirements will be printed out
      #           together with header and a summary at the end
      #           when false only not fulfilled requirements will be
      #           printed
      # When any requirements is not fulfilled header and summary will
      # be displayed regardless of verbose value
      def check(verbose = true)
        structure = Shelly::StructureValidator.new

        if verbose or structure.invalid? or structure.warnings?
          say "Checking Shelly Cloud requirements\n\n"
        end

        print_check(structure.gemfile?, "Gemfile is present",
          "Gemfile is missing in git repository",
          :show_fulfilled => verbose)

        print_check(structure.gemfile_lock?, "Gemfile.lock is present",
          "Gemfile.lock is missing in git repository",
          :show_fulfilled => verbose)

        print_check(structure.config_ru?, "config.ru is present",
          "config.ru is missing",
          :show_fulfilled => verbose)

        print_check(structure.rakefile?, "Rakefile is present",
          "Rakefile is missing",
          :show_fulfilled => verbose)

        print_check(structure.gem?("shelly-dependencies"),
          "Gem 'shelly-dependencies' is present",
          "Gem 'shelly-dependencies' is missing, we recommend to install it\n    See more at https://shellycloud.com/documentation/requirements#shelly-dependencies",
          :show_fulfilled => verbose || structure.warnings?, :failure_level => :warning)

        print_check(structure.gem?("thin") || structure.gem?("puma"),
          "Web server gem is present",
          "Missing web server gem in Gemfile. Currently supported: 'thin' and 'puma'",
          :show_fulfilled => verbose)

        print_check(structure.gem?("rake"), "Gem 'rake' is present",
          "Gem 'rake' is missing in the Gemfile", :show_fulfilled => verbose)

        print_check(structure.task?("db:migrate"), "Task 'db:migrate' is present",
          "Task 'db:migrate' is missing", :show_fulfilled => verbose)

        print_check(structure.task?("db:setup"), "Task 'db:setup' is present",
          "Task 'db:setup' is missing", :show_fulfilled => verbose)

        cloudfile = Cloudfile.new
        if cloudfile.present?
          cloudfile.clouds.each do |app|
            if app.cloud_databases.include?('postgresql')
              print_check(structure.gem?("pg") || structure.gem?("postgres"),
                "Postgresql driver is present for '#{app}' cloud",
                "Postgresql driver is missing in the Gemfile for '#{app}' cloud,\n    we recommend adding 'pg' gem to Gemfile",
                :show_fulfilled => verbose)
            end

            if app.delayed_job?
              print_check(structure.gem?("delayed_job"),
                "Gem 'delayed_job' is present for '#{app}' cloud",
                "Gem 'delayed_job' is missing in the Gemfile for '#{app}' cloud",
                :show_fulfilled => verbose)
            end

            if app.whenever?
              print_check(structure.gem?("whenever"),
                "Gem 'whenever' is present for '#{app}' cloud",
                "Gem 'whenever' is missing in the Gemfile for '#{app}' cloud",
                :show_fulfilled => verbose)
            end

            if app.sidekiq?
              print_check(structure.gem?("sidekiq"),
                "Gem 'sidekiq' is present for '#{app}' cloud",
                "Gem 'sidekiq' is missing in the Gemfile for '#{app}' cloud",
                :show_fulfilled => verbose)
            end
          end
        end

        if structure.valid?
          if verbose
            say "\nGreat! Your application is ready to run on Shelly Cloud"
          end
        else
          say "\nFix points marked with #{red("✗")} to run your application on the Shelly Cloud"
          say "See more about requirements on https://shellycloud.com/documentation/requirements"
        end

        structure.valid?
      rescue Bundler::BundlerError => e
        say_new_line
        say_error e.message, :with_exit => false
        say_error "Try to run `bundle install`"
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
              when "--cloud", "-c"
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

        def overwrite_remote?(app)
          git_remote = app.git_remote_exist?
          !git_remote or (git_remote and yes?("Git remote #{app} exists, overwrite (yes/no): "))
        end

        def ask_for_password(options = {})
          options = {:with_confirmation => true}.merge(options)
          loop do
            say "Password: "
            password = echo_disabled { $stdin.gets.strip }
            say_new_line
            return password unless options[:with_confirmation]
            say "Password confirmation: "
            password_confirmation = echo_disabled { $stdin.gets.strip }
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
          default_code_name = Shelly::App.guess_code_name
          code_name = ask("Cloud code name (#{Shelly::App.guess_code_name} - default):")
          code_name.blank? ? default_code_name : code_name
        end

        def ask_for_databases
          kinds = Shelly::App::DATABASE_CHOICES
          databases = ask("Which database do you want to use #{kinds.join(", ")} (postgresql - default):")
          begin
            databases = databases.split(/[\s,]/).reject(&:blank?)
            valid = valid_databases?(databases)
            break if valid
            databases = ask("Unknown database kind. Supported are: #{kinds.join(", ")}:")
          end while not valid

          databases.empty? ? ["postgresql"] : databases
        end

        def ask_for_organization(default_name)
          organizations = Shelly::User.new.organizations
          if organizations.count > 1
            count = organizations.count
            option_selected = 0
            loop do
              say "Select organization for this cloud:"
              say_new_line
              say "existing organizations:"

              organizations.each_with_index do |organization, i|
                print_wrapped "#{i + 1}) #{organization.name}", :ident => 2
              end
              say_new_line
              say "new organization (default as code name):"

              print_wrapped "#{count + 1}) #{default_name}", :ident => 2

              option_selected = ask("Option:")
              break if ('1'..(count + 1).to_s).include?(option_selected)
            end

            if (1..count).include?(option_selected.to_i)
              return organizations[option_selected.to_i - 1].name
            end
          end
        end

        def info_adding_cloudfile_to_repository
          say_new_line
          say "Project is now configured for use with Shelly Cloud:", :green
          say "You can review changes using", :green
          say "  git status"
        end

        def info_deploying_to_shellycloud(remote)
          say_new_line
          say "When you make sure all settings are correct please issue following commands:", :green
          say "  git add ."
          say '  git commit -m "Application added to Shelly Cloud"'
          say "  git push"
          say_new_line
          say "Deploy to your cloud using:", :green
          say "  git push #{remote} master"
          say_new_line
        end
      end
    end
  end
end
