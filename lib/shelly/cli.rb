require "shelly"
require "shelly/user"

module Shelly
  class CLI < Thor
    include Helpers
    include Thor::Actions

    map %w(-v --version) => :version
    desc "version", "Displays shelly version"
    def version
      say "shelly version #{Shelly::VERSION}"
    end

    desc "register", "Registers new user at Shelly Cloud"
    def register
      email_question = User.guess_email.blank? ? "Email:" : "Email (default #{User.guess_email}):"
      email = ask(email_question)
      email = User.guess_email if email.blank?
      password = ask_for_password

      if email.blank? or password.blank?
        say "Email and password can't be blank" and exit 1
      end

      user = User.new(email, password)
      if user.register
        say "Successfully registered!\nCheck you mailbox for email confirmation"
      end
    rescue Client::APIError => e
      if e.message == "Validation Failed"
        e.errors.each { |error| say "#{error.first} #{error.last}" }
      end
    end

    no_tasks do
      def ask_for_password
        say "Password: "
        echo_off
        password = $stdin.gets.strip
        echo_on
        password
      end
    end
  end
end
