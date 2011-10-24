require "shelly"
require "thor/group"
require "shelly/cli/users"

module Shelly
  module CLI
    class Main < Thor
      include Thor::Actions
      include Helpers
      register(Users, "users", "users <command>", "Manages users using this app")

      map %w(-v --version) => :version
      desc "version", "Displays shelly version"
      def version
        say "shelly version #{Shelly::VERSION}"
      end

      desc "register [EMAIL]", "Registers new user account on Shelly Cloud"
      def register(email = nil)
      	user = User.new
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
          e.errors.each do |error|
            say_error "#{error.first} #{error.last}", :with_exit => false
          end
          exit 1
        end
       rescue RestClient::Conflict
       	say_error "User with your ssh key already exists.", :with_exit => false
				say_error "You can login using: shelly login [EMAIL]", :with_exit => false
				exit 1
      end

      desc "login [EMAIL]", "Logins user to Shelly Cloud"
      def login(email = nil)
        user = User.new(email || ask_for_email, ask_for_password(:with_confirmation => false))
        user.login
        say "Login successful"
        say "Uploading your public SSH key"
        user.upload_ssh_key
        say "You have following applications available:", :green
        user.apps.each do |app|
          say "  #{app["code_name"]}"
        end
      rescue RestClient::Unauthorized
        say_error "Wrong email or password", :with_exit => false
        say_error "You can reset password by using link:", :with_exit => false
        say_error "https://admin.winniecloud.com/users/password/new", :with_exit => false
        exit 1
      rescue Client::APIError => e
        if e.validation?
          e.errors.each { |error| say_error "#{error.first} #{error.last}", :with_exit => false }
          exit 1
        end
      end

      method_option :code_name, :type => :string, :aliases => "-c",
        :desc => "Unique code_name of your application"
      method_option :environment, :type => :string, :aliases => "-e",
        :desc => "Environment that your application will be running"
      method_option :databases, :type => :array, :aliases => "-d",
        :banner => "#{Shelly::App::DATABASE_KINDS.join(' ')}",
        :desc => "Array of databases of your choice"
      method_option :domains, :type => :array,
        :banner => "CODE_NAME.shellycloud.com YOUR_DOMAIN.com",
        :desc => "Array of your domains"
      desc "add", "Adds new application to Shelly Cloud"
      def add
        say_error "Must be run inside your project git repository" unless App.inside_git_repository?
        check_options(options)
        @app = Shelly::App.new
        @app.purpose = options["environment"] || ask_for_purpose
        @app.code_name = options["code_name"] || ask_for_code_name
        @app.databases = options["databases"] || ask_for_databases
        @app.domains = options["domains"]
        @app.create

        say "Adding remote #{@app.purpose} #{@app.git_url}", :green
        @app.add_git_remote

        say "Creating Cloudfile", :green
        @app.create_cloudfile

        say "Provide billing details. Opening browser...", :green
        @app.open_billing_page

        info_adding_cloudfile_to_repository
        info_deploying_to_shellycloud
      rescue Client::APIError => e
        if e.validation?
          e.errors.each { |error| say_error "#{error.first} #{error.last}", :with_exit => false }
          exit 1
        end
      end

      # FIXME: move to helpers
      no_tasks do
        def check_options(options)
          unless ["environment", "code_name", "databases", "domains"].all? do |option|
            options.include?(option.to_s) && options[option.to_s] != option.to_s
          end && valid_databases?(options["databases"])
            say "Wrong parameters. See 'shelly help add' for further information"
            exit 1
          end unless options.empty?
        end

        def valid_databases?(databases)
          kinds = Shelly::App::DATABASE_KINDS
          databases.all? { |kind| kinds.include?(kind) }
        end

        def ask_for_email
          email_question = User.guess_email.blank? ? "Email:" : "Email (#{User.guess_email} - default):"
          email = ask(email_question)
          email = email.blank? ? User.guess_email : email
          return email if email.present?
          say_error "Email can't be blank, please try again"
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

        def ask_for_purpose
          purpose = ask("How will you use this system (production - default,staging):")
          purpose.blank? ? "production" : purpose
        end

        def ask_for_code_name
          default_code_name = "#{Shelly::App.guess_code_name}-#{@app.purpose}"
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
          say "Deploy to #{@app.purpose} using:", :green
          say "  git push #{@app.purpose} master"
          say_new_line
        end
      end
    end
  end
end

