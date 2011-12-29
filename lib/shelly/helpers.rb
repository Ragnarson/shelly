module Shelly
  module Helpers
    def echo_disabled
      system "stty -echo"
      value = yield
      system "stty echo"
      value
    end

    def say_new_line
      say "\n"
    end

    # FIXME: errors should be printed on STDERR
    def say_error(message, options = {})
      options = {:with_exit => true}.merge(options)
      say  message, :red
      exit 1 if options[:with_exit]
    end

    def ask_for_email(options = {})
      options = {:guess_email => true}.merge(options)
      email_question = options[:guess_email] && !User.guess_email.blank? ? "Email (#{User.guess_email} - default):" : "Email:"
      email = ask(email_question)
      email = email.blank? ? User.guess_email : email
      return email if email.present?
      say_error "Email can't be blank, please try again"
    end

    def ask_to_delete_files
      delete_files_question = "I want to delete all files stored on Shelly Cloud (yes/no):"
      delete_files = ask(delete_files_question)
      exit 1 unless delete_files == "yes"
    end

    def ask_to_delete_database
      delete_database_question = "I want to delete all database data stored on Shelly Cloud (yes/no):"
      delete_database = ask(delete_database_question)
      exit 1 unless delete_database == "yes"
    end

    def ask_to_delete_application
      delete_application_question = "I want to delete the application (yes/no):"
      delete_application = ask(delete_application_question)
      exit 1 unless delete_application == "yes"
    end

    def inside_git_repository?
      say_error "Must be run inside your project git repository" unless App.inside_git_repository?
    end

    def cloudfile_present?
      say_error "No Cloudfile found" unless Cloudfile.present?
    end

    def logged_in?
      user = Shelly::User.new
      user.token
      user
    rescue Client::APIError => e
      if e.unauthorized?
        say_error "You are not logged in. To log in use:", :with_exit => false
        say "  shelly login"
        exit 1
      end
    end

    def multiple_clouds(cloud, action, message)
      clouds = Cloudfile.new.clouds
      if clouds.count > 1 && cloud.nil?
        say "You have multiple clouds in Cloudfile. #{message}"
        say "  shelly #{action} --cloud #{clouds.first}"
        say "Available clouds:"
        clouds.each do |cloud|
          say " * #{cloud}"
        end
        exit 1
      end
      @app = Shelly::App.new
      @app.code_name = cloud || clouds.first
    end

  end
end
