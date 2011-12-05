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

    def check_clouds
        @cloudfile = Shelly::Cloudfile.new
        @user = Shelly::User.new
        user_apps = @user.apps.map { |cloud| cloud['code_name'] }
        unless @cloudfile.clouds.all? { |cloud| user_apps.include?(cloud) }
          errors = (@cloudfile.clouds - user_apps).map do |cloud|
            "You have no access to '#{cloud}' cloud defined in Cloudfile"
          end
          raise Shelly::Client::APIError.new({:message => "Unauthorized",
            :errors => errors}.to_json)
        end
        [@cloudfile, @user]
      end
  end
end

