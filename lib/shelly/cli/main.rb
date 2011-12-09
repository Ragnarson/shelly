require "shelly/cli/command"
require "shelly/cli/user"

module Shelly
  module CLI
    class Main < Command
      include Thor::Actions
      include Helpers
      register(User, "user", "user <command>", "Manages users using this cloud")
      check_unknown_options!

      map %w(-v --version) => :version
      desc "version", "Displays shelly version"
      def version
        say "shelly version #{Shelly::VERSION}"
      end

      desc "register [EMAIL]", "Registers new user account on Shelly Cloud"
      def register(email = nil)
      	user = Shelly::User.new
      	user.ssh_key_registered?
        say "Registering with email: #{email}" if email
				user.email = (email || ask_for_email)
				user.password = ask_for_password
        user.register
        if user.ssh_key_exists?
          say "Uploading your public SSH key from #{user.ssh_key_path}"
        end
        say "Successfully registered!"
        say "Check you mailbox for email address confirmation"
      rescue Client::APIError => e
        if e.validation?
          e.each_error { |error| say_error "#{error}", :with_exit => false }
          exit 1
        end
      rescue RestClient::Conflict
        say_error "User with your ssh key already exists.", :with_exit => false
        say_error "You can login using: shelly login [EMAIL]", :with_exit => false
        exit 1
      rescue Errno::ENOENT => e
        say_error e, :with_exit => false
        say_error "Use ssh-keygen to generate ssh key pair"
      end

      desc "login [EMAIL]", "Logs user in to Shelly Cloud"
      def login(email = nil)
        user = Shelly::User.new
      	raise Errno::ENOENT, user.ssh_key_path unless user.ssh_key_exists?
        user.email = email || ask_for_email
        user.password = ask_for_password(:with_confirmation => false)
        user.login
        say "Login successful"
        # FIXME: remove conflict boolean, move it to rescue block
        begin user.upload_ssh_key
          conflict = false
        rescue RestClient::Conflict
          conflict = true
        end
        say "Uploading your public SSH key" if conflict == false
        list
      rescue Client::APIError => e
        if e.validation?
          e.each_error { |error| say_error "#{error}", :with_exit => false }
        end
        if e.unauthorized?
          say_error "Wrong email or password", :with_exit => false
          say_error "You can reset password by using link:", :with_exit => false
          say_error "#{e.url}", :with_exit => false
        end
        exit 1
      rescue Errno::ENOENT => e
        say_error e, :with_exit => false
        say_error "Use ssh-keygen to generate ssh key pair"
      end

      method_option "code-name", :type => :string, :aliases => "-c",
        :desc => "Unique code-name of your cloud"
      method_option :databases, :type => :array, :aliases => "-d",
        :banner => Shelly::App::DATABASE_KINDS.join(', '),
        :desc => "Array of databases of your choice"
      method_option :domains, :type => :array,
        :banner => "CODE-NAME.shellyapp.com, YOUR-DOMAIN.com",
        :desc => "Array of your domains"
      desc "add", "Adds new cloud to Shelly Cloud"
      def add
        say_error "Must be run inside your project git repository" unless App.inside_git_repository?
        check_options(options)
        @app = Shelly::App.new
        @app.code_name = options["code-name"] || ask_for_code_name
        @app.databases = options["databases"] || ask_for_databases
        @app.domains = options["domains"]
        @app.create

        say "Adding remote production #{@app.git_url}", :green
        @app.add_git_remote

        say "Creating Cloudfile", :green
        @app.create_cloudfile

        say "Provide billing details. Opening browser...", :green
        @app.open_billing_page

        info_adding_cloudfile_to_repository
        info_deploying_to_shellycloud

      rescue Client::APIError => e
        if e.validation?
          e.each_error { |error| say_error error, :with_exit => false }
          say_new_line
          say_error "Fix erros in the below command and type it again to create your cloud" , :with_exit => false
          say_error "shelly add --code-name=#{@app.code_name} --databases=#{@app.databases.join} --domains=#{@app.code_name}.shellyapp.com"
        end
      end

      desc "list", "Lists all your clouds"
      def list
        user = Shelly::User.new
        user.token
        apps = user.apps
        unless apps.empty?
          say "You have following clouds available:", :green
          print_table(apps.map do |app|
            state = app["state"] == "deploy_failed" ? " (Support has been notified)" : ""
            [app["code_name"], "|  #{app["state"].gsub("_", " ")}#{state}"]
          end, :ident => 2)
        else
          say "You have no clouds yet", :green
        end
      rescue Client::APIError => e
        if e.unauthorized?
          say_error "You are not logged in, use `shelly login`"
        end
      end
      map "status" => :list

      desc "ip", "Lists clouds IP's"
      def ip
        say_error "Must be run inside your project git repository" unless App.inside_git_repository?
        say_error "No Cloudfile found" unless Cloudfile.present?
        @cloudfile = Cloudfile.new
        @cloudfile.clouds.each do |cloud|
          begin
            @app = App.new(cloud)
            say "Cloud #{cloud}:", :green
            ips = @app.ips
            print_wrapped "Web server IP: #{ips['web_server_ip']}", :ident => 2
            print_wrapped "Mail server IP: #{ips['mail_server_ip']}", :ident => 2
          rescue Client::APIError => e
            if e.unauthorized?
              say_error "You have no access to '#{cloud}' cloud defined in Cloudfile", :with_exit => false
            else
              say_error e.message, :with_exit => false
            end
          end
        end
      end

      desc "start [CODE-NAME]", "Starts specific cloud"
      def start(cloud = nil)
        logged_in?
        say_error "No Cloudfile found" unless Cloudfile.present?
        cloudfile = Cloudfile.new
        multiple_clouds(cloudfile.clouds, cloud)
        @app.start
        say "Starting cloud #{@app.code_name}. Check status with:", :green
        say "  shelly list"
      rescue RestClient::Conflict => e
        response =  JSON.parse(e.response)
        case response['state']
        when "running"
          say_error "Not starting: cloud '#{@app.code_name}' is already running"
        when "deploying", "configuring"
          say_error "Not starting: cloud '#{@app.code_name}' is currently deploying"
        when "no_code"
          say_error "Not starting: no source code provided", :with_exit => false
          say_error "Push source code using:", :with_exit => false
          say       "  git push production master"
        when "deploy_failed", "configuration_failed"
          say_error "Not starting: deployment failed", :with_exit => false
          say_error "Support has been notified", :with_exit => false
          say_error "See #{response['link']} for reasons of failure"
        when "no_billing"
          say_error "Please fill in billing details to start foo-production. Opening browser.", :with_exit => false
          @app.open_billing_page
        end
        exit 1
      rescue Client::APIError => e
        if e.unauthorized?
          say_error "You have no access to '#{@app.code_name}' cloud defined in Cloudfile"
        end
      end

      desc "stop [CODE-NAME]", "Stops specific cloud"
      def stop(cloud = nil)
        logged_in?
        say_error "No Cloudfile found" unless Cloudfile.present?
        cloudfile = Cloudfile.new
        multiple_clouds(cloudfile.clouds, cloud, "stop")
        @app.stop
        say "Cloud '#{@app.code_name}' stopped"
      rescue Client::APIError => e
        if e.unauthorized?
          say_error "You have no access to '#{@app.code_name}' cloud defined in Cloudfile"
        end
      end

      desc "delete CODE-NAME", "Delete cloud from Shelly Cloud"
      def delete(code_name = nil)
        user = Shelly::User.new
        user.token
        if code_name.present?
          app = Shelly::App.new
          say "You are about to delete application: #{code_name}."
          say "Press Control-C at any moment to cancel."
          say "Please confirm each question by typing yes and pressing Enter."
          say_new_line
          ask_to_delete_files
          ask_to_delete_database
          ask_to_delete_application
          app.delete(code_name)
          say_new_line
          say "Scheduling application delete - done"
          if App.inside_git_repository?
            app.remove_git_remote
            say "Removing git remote - done"
          else
            say "Missing git remote"
          end
        else
          say_error "Missing CODE-NAME", :with_exit => false
          say_error "Use: shelly delete CODE-NAME"
        end
      rescue Client::APIError => e
        say_error e.message
      end

      # FIXME: move to helpers
      no_tasks do
        def multiple_clouds(clouds, cloud, action = "start")
          if clouds.count > 1 && cloud.nil?
            say "You have multiple clouds in Cloudfile. Select which to #{action} using:"
            say "  shelly #{action} #{clouds.first}"
            say "Available clouds:"
            clouds.each do |cloud|
              say " * #{cloud}"
            end
            exit 1
          end
          @app = Shelly::App.new
          @app.code_name = cloud.nil? ? clouds.first : cloud
        end

        def check_options(options)
          unless options.empty?
            unless ["code-name", "databases", "domains"].all? do |option|
              options.include?(option.to_s) && options[option.to_s] != option.to_s
            end && valid_databases?(options["databases"])
              say_error "Try 'shelly help add' for more information"
            end
          end
        end

        def valid_databases?(databases)
          kinds = Shelly::App::DATABASE_KINDS
          databases.all? { |kind| kinds.include?(kind) }
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
          default_code_name = "#{Shelly::App.guess_code_name}-production"
          code_name = ask("Cloud code name (#{default_code_name} - default):")
          code_name.blank? ? default_code_name : code_name
        end

        def ask_for_databases
          kinds = Shelly::App::DATABASE_KINDS
          databases = ask("Which database do you want to use #{kinds.join(", ")} (postgresql - default):")
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
          say "Project is now configured for use with Shell Cloud:", :green
          say "You can review changes using", :green
          say "  git status"
        end

        def info_deploying_to_shellycloud
          say_new_line
          say "When you make sure all settings are correct please issue following commands:", :green
          say "  git add ."
          say '  git commit -m "Application added to Shelly Cloud"'
          say "  git push"
          say_new_line
          say "Deploy to production using:", :green
          say "  git push production master"
          say_new_line
        end
      end
    end
  end
end
