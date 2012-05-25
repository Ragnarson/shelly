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

    def ask_for_acceptance_of_terms
      acceptance_question = "Do you accept the Terms of Service of Shelly Cloud (https://shellycloud.com/terms_of_service) (yes/no)"
      acceptance = ask(acceptance_question)
      unless acceptance == "yes"
        say_error "You must accept the Terms of Service to use Shelly Cloud"
      end
    end

    def ask_to_stop_application
      stop_question = "Are you sure you want to shut down your application (yes/no):"
      stop_application = ask(stop_question)
      exit 1 unless stop_application == "yes"
    end

    def inside_git_repository?
      say_error "Must be run inside your project git repository" unless App.inside_git_repository?
    end

    def cloudfile_present?
      say_error "No Cloudfile found" unless Cloudfile.new.present?
    end

    def ask_to_restore_database
      delete_application_question = "I want to restore the database (yes/no):"
      delete_application = ask(delete_application_question)
      say_new_line say_error "Canceled" unless delete_application == "yes"
    end

    def logged_in?
      user = Shelly::User.new
      user.token
      user
    rescue Client::UnauthorizedException
      say_error "You are not logged in. To log in use: `shelly login`"
    end

    def command_exists?(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each { |ext|
          exe = "#{path}/#{cmd}#{ext}"
          return exe if File.executable? exe
        }
      end
      return false
    end

    def multiple_clouds(cloud, action)
      clouds = Cloudfile.new.clouds
      if clouds && clouds.count > 1 && cloud.nil?
        say_error "You have multiple clouds in Cloudfile.", :with_exit => false
        say "Select cloud using `shelly #{action} --cloud #{clouds.first}`"
        say "Available clouds:"
        clouds.each do |cloud|
          say " * #{cloud}"
        end
        exit 1
      end
      unless Cloudfile.new.present? || cloud
        say_error "You have to specify cloud.", :with_exit => false
        say "Select cloud using `shelly #{action} --cloud CLOUD_NAME`"
        Shelly::CLI::Main.new.list
        exit 1
      end

      app = Shelly::App.new
      app.code_name = cloud || clouds.first
      app
    end

    def print_logs(logs)
      logs['entries'].each do |entry|
        say "%8.8s | %s\n" % entry
      end
    end
  end
end
