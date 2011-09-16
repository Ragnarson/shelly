require "shelly/user"

module Shelly
  module CLI
    class Account < Thor
      namespace :account
      include Helpers

      desc "register", "Registers new user account on Shelly Cloud"
      def register
        email = ask_for_email
        password = ask_for_password

        # FIXME: ask user in loop, until he enters valid values
        if email.blank? or password.blank?
          say "Email and password can't be blank" and exit 1
        end

        user = User.new(email, password)
        user.register
        if user.ssh_key_exists?
          say "Uploading your public SSH key from #{user.ssh_key_path}"
        end
        say "Successfully registered!"
        say "Check you mailbox for email confirmation"
      rescue Client::APIError => e
        if e.message == "Validation Failed"
          e.errors.each { |error| say "#{error.first} #{error.last}" }
        end
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
          email.blank? ? User.guess_email : email
        end

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
end
