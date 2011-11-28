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

    def logged_in?
      user = Shelly::User.new
      user.load_credentials
      user.login
    rescue Client::APIError => e
      say_error "You are not logged in, use `shelly login` to log in"
    end

    def inside_git_repository?
      say_error "Must be run inside your project git repository" unless App.inside_git_repository?
    end

    def cloudfile_present?
      say_error "No Cloudfile found" unless Cloudfile.present?
    end

  end
end
