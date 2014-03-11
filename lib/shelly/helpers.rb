# encoding: utf-8
module Shelly
  module Helpers
    def say_new_line
      say "\n"
    end

    # FIXME: errors should be printed on STDERR
    def say_error(message, options = {})
      options = {:with_exit => true}.merge(options)
      say  message, :red
      exit 1 if options[:with_exit]
    end

    def say_warning(message)
      say message, :yellow
    end

    # Extracted into a helper so can be used when adding cloud Main#add and
    # Organization#add
    def create_new_organization(options = {})
      organization = Shelly::Organization.new
      organization.name = ask_for_organization_name
      organization.redeem_code = options["redeem-code"]
      organization.create
      say "Organization '#{organization.name}' created", :green
      organization.name
    end

    def ask_for_email(options = {})
      options = {:guess_email => true}.merge(options)
      email_question = options[:guess_email] && !User.guess_email.blank? ? "Email (#{User.guess_email} - default):" : "Email:"
      email = ask(email_question)
      email = email.blank? ? User.guess_email : email
      return email if email.present?
      say_error "Email can't be blank, please try again"
    end

    def ask_to_delete_application(app)
      code_name = ask "Please confirm with the name of the cloud:"

      unless code_name == app.code_name
        say_error "The name does not match. Operation aborted."
        exit 1
      end
    end

    def ask_for_acceptance_of_terms
      acceptance_question = "Do you accept the Terms of Service of Shelly Cloud (https://shellycloud.com/terms_of_service) (yes/no)"
      unless yes?(acceptance_question)
        say_error "You must accept the Terms of Service to use Shelly Cloud"
      end
    end

    def ask_to_reset_database
      reset_database_question = "I want to reset the database (yes/no):"
      exit 1 unless yes?(reset_database_question)
    end

    def ask_for_organization_name
      default_name = default_name_from_dir_name
      name = ask("Organization name (#{default_name} - default):")
      name.blank? ? default_name : name
    end

    def default_name_from_dir_name
      "#{File.basename(Dir.pwd)}".downcase.dasherize
    end

    def inside_git_repository?
      unless App.inside_git_repository?
        say_error %q{Current directory is not a git repository.
You need to initialize repository with `git init`.
More info at http://git-scm.com/book/en/Git-Basics-Getting-a-Git-Repository}
      end
    end

    def cloudfile_present?
      say_error "No Cloudfile found" unless Cloudfile.new.present?
    end

    def ask_to_restore_database
      question = "I want to restore the database (yes/no):"
      say_new_line say_error "Canceled" unless yes?(question)
    end

    def logged_in?
      user = Shelly::User.new
      user.authorize!
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

      cloud ? Shelly::App.new(cloud) : clouds.first
    end

    def print_logs(logs)
      logs['entries'].each do |entry|
        say "%s %s" % entry
      end
    end

    def green(string)
      "\e[32m#{string}\e[0m"
    end

    def red(string)
      "\e[31m#{string}\e[0m"
    end

    def yellow(string)
      "\e[33m#{string}\e[0m"
    end

    def print_check(check, success_message, failure_message, options = {})
      return if check && !options[:show_fulfilled]
      message = check ? success_message : failure_message
      indicator = if check
                    green("✓")
                  else
                    options[:failure_level] == :warning ? yellow("ϟ") : red("✗")
                  end
      say "  #{indicator} #{message}"
    end

    def deployment_progress(app, deployment_id, action_name)
      printed_messages = []
      loop do
        @deployment = app.deployment(deployment_id)
        new_messages = @deployment["messages"] - printed_messages
        new_messages.each do |message|
          color = (message =~ /failed/) ? :red : :green
          say " ---> #{message}", color
          printed_messages << message
        end

        break if @deployment["state"] != "running"
        sleep 5
      end

      say_new_line

      if @deployment["result"] == "success"
        say "#{action_name} successful", :green
      else
        say "#{action_name} failed. See logs with `shelly deploy show last --cloud #{app}`", :red
      end
    end

    def apps_table(apps)
      apps.map do |app|
        msg = info_show_last_deploy_logs(app)
        [app.code_name, "|  #{app.state_description}#{msg}"]
      end
    end

    def info_show_last_deploy_logs(app)
      if app.in_deploy_failed_state? && !app.maintenance?
        " (deployment log: `shelly deploys show last -c #{app}`)"
      end
    end
  end
end
