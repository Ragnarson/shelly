require "shelly/user"

module Shelly
  module CLI
    class Account < Thor
      namespace :account
      include Helpers

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
        if e.message == "Validation Failed"
          e.errors.each { |error| say "#{error.first} #{error.last}" }
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
      rescue RestClient::Unauthorized
        say "Wrong email or password or your email is unconfirmend"
        exit 1
      end

      # Fix for bug with displaying help for subcommands
      # http://stackoverflow.com/questions/5663519/namespacing-thor-commands-in-a-standalone-ruby-executable
      def self.banner(task, namespace = true, subcommand = false)
        "#{basename} #{task.formatted_usage(self, true, subcommand)}"
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
      end
    end
  end
end
