require "shelly/app"

module Shelly
  module CLI
    class Apps < Thor
      include Helpers
      namespace :apps

      desc "add", "Adds new application to Shelly Cloud"
      def add
        say_error "Must be run inside your project git repository" unless App.inside_git_repository?
        @app = Shelly::App.new
        @app.purpose = ask_for_purpose
        @app.code_name = ask_for_code_name
        @app.databases = ask_for_databases
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
        if e.message == "Validation Failed"
          e.errors.each { |error| say "#{error.first} #{error.last}" }
          exit 1
        end
      end

      no_tasks do
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
          say "  git diff"
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
        end
      end
    end
  end
end

