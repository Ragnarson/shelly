require "shelly"
require "thor/group"

module Shelly
  module CLI
    class Main < Thor
      include Thor::Actions
      include Helpers

      map %w(-v --version) => :version
      desc "version", "Displays shelly version"
      def version
        say "shelly version #{Shelly::VERSION}"
      end

      desc "register [EMAIL]", "Registers new user account on Shelly Cloud"
      def register(email = nil)
        say "Registering with email: #{email}" if email
        user = User.new(email || ask_for_email, ask_for_password)
        user.register
        if user.ssh_key_exists?
          say "Uploading your public SSH key from #{user.ssh_key_path}"
        end
        say "Successfully registered!"
        say "Check you mailbox for email address confirmation"
      rescue Client::APIError => e
        if e.validation?
          e.errors.each do |error|
            say "#{error.first} #{error.last}"
          end
          exit 1
        end
      end

      desc "login [EMAIL]", "Logins user to Shelly Cloud"
      def login(email = nil)
        user = User.new(email || ask_for_email, ask_for_password(false))
        user.login
        say "Login successful"
        say "Uploading your public SSH key"
        user.upload_ssh_key
        say "You have following applications available:", :green
        user.apps.each do |app|
          say "  #{app["code_name"]}"
        end
      rescue RestClient::Unauthorized
        say "Wrong email or password or your email is unconfirmend"
        exit 1
      rescue Client::APIError
        if e.validation?
          e.errors.each { |error| say "#{error.first} #{error.last}" }
          exit 1
        end
      end

      desc "add", "Adds new application to Shelly Cloud"
      def add
        say_error "Must be run inside your project git repository" unless App.inside_git_repository?

        @app = Shelly::App.new
        @app.purpose = ask_for_purpose
        @app.code_name = ask_for_code_name
        @app.databases = ask_for_databases
        @app.create

        unless @app.remote_exists?
          say "Adding remote #{@app.purpose} #{@app.git_url}", :green
          @app.add_git_remote
        else
          say "Remote #{@app.purpose} already exists"
          if yes?("Would you like to overwrite remote #{@app.purpose} with #{@app.git_url} (Y/N)?:")
            @app.add_git_remote(true)
          end
        end

        say "Creating Cloudfile", :green
        @app.create_cloudfile

        say "Provide billing details. Opening browser...", :green
        @app.open_billing_page

        info_adding_cloudfile_to_repository
        info_deploying_to_shellycloud
      rescue Client::APIError => e
        if e.validation?
          e.errors.each { |error| say "#{error.first} #{error.last}" }
          exit 1
        end
      end

      # FIXME: move to helpers
      no_tasks do
        def ask_for_email
          email_question = User.guess_email.blank? ? "Email:" : "Email (#{User.guess_email} - default):"
          email = ask(email_question)
          email = email.blank? ? User.guess_email : email
          return email if email.present?
          say_error "Email can't be blank, please try again"
        end

        def ask_for_password(with_confirmation = true)
          loop do
            say "Password: "
            password = echo_disabled { $stdin.gets.strip }
            say_new_line
            return password unless with_confirmation
            say "Password confirmation: "
            password_confirmation = echo_disabled { $stdin.gets.strip }
            say_new_line
            if password.present?
              return password if password == password_confirmation
              say "Password and password confirmation don't match, please type them again"
            else
              say "Password can't be blank"
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
            databases = databases.split(/[\s,]/)
            valid = databases.all? { |kind| kinds.include?(kind) }
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
