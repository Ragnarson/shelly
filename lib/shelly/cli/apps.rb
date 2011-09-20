require "shelly/app"

module Shelly
  module CLI
    class Apps < Thor
      namespace :apps

      desc "add", "Adds new application to Shelly Cloud"
      def add
        @app = Shelly::App.new
        @app.purpose = ask_for_purpose
        @app.code_name = ask_for_code_name
        @app.databases = ask_for_databases
        @app.add_git_remote
        @app.create_cloudfile
        @app.open_billing_page

        info_adding_cloudfile_to_repository
        info_deploying_to_shellycloud
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
          say("Project is now configured for use with Shell Cloud:")
          say("You can review changes using")
          say("  git diff")
        end

        def info_deploying_to_shellycloud
          say("When you make sure all settings are correct please issue following commands:")
          say("  git add .")
          say('  git commit -m "Application added to Shelly Cloud"')
          say("  git push")
          say("Deploy to #{@app.purpose} using:")
          say("  git push #{@app.purpose} master")
        end
      end
    end
  end
end

