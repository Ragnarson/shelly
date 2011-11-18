require "shelly"
require "thor/group"
require "shelly/cli/user"

module Shelly
  module CLI
    class Main < Thor
      include Thor::Actions
      include Helpers
      register(User, "user", "user <command>", "Manages users using this app")
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

      desc "login [EMAIL]", "Logins user to Shelly Cloud"
      def login(email = nil)
        user = Shelly::User.new(email || ask_for_email, ask_for_password(:with_confirmation => false))
        user.login
        say "Login successful"
        user.upload_ssh_key
        say "Uploading your public SSH key"
        say "You have following applications available:", :green
        user.apps.each do |app|
          say "  #{app["code_name"]}"
        end
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
      rescue RestClient::Conflict
        say "You have following applications available:", :green
        user.apps.each do |app|
          say "  #{app["code_name"]}"
        end
        exit 1
      end

      method_option "code-name", :type => :string, :aliases => "-c",
        :desc => "Unique code_name of your application"
      method_option :databases, :type => :array, :aliases => "-d",
        :banner => "#{Shelly::App::DATABASE_KINDS.join(', ')}",
        :desc => "Array of databases of your choice"
      method_option :domains, :type => :array,
        :banner => "CODE-NAME.shellyapp.com, YOUR-DOMAIN.com",
        :desc => "Array of your domains"
      desc "add", "Adds new application to Shelly Cloud"
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
          e.each_error { |error| say_error "#{error}", :with_exit => false }
          say_new_line
          say_error "Fix erros in the below command and type it again to create your application" , :with_exit => false
          say_error "shelly add --code-name=#{@app.code_name} --databases=#{@app.databases.join} --domains=#{@app.code_name}.shellyapp.com"
        end
      end

      # FIXME: move to helpers
      no_tasks do
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
          code_name = ask("Application code name (#{default_code_name} - default):")
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

