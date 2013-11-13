require 'shelly/organization'

module Shelly
  class User < Model
    def apps
      shelly.apps.map do |attributes|
        Shelly::App.from_attributes(attributes)
      end
    end

    def organizations
      shelly.organizations.map do |attributes|
        Shelly::Organization.new(attributes)
      end
    end

    def email
      shelly.user_email
    end

    def register(email, password)
      shelly.register_user(email, password)
    end

    def authorize!
      if credentials_exists?
        email, password = File.read(credentials_path).split("\n")
        shelly.authorize_with_email_and_password(email, password)
        delete_credentials
      else
        shelly.authorize!
      end
    end

    def login(email, password)
      delete_credentials # clean up previous auth storage

      shelly.authorize_with_email_and_password(email, password)
    end

    def logout
      delete_credentials # clean up previous auth storage
      shelly.forget_authorization
    end

    def ssh_keys
      @keys ||= SshKeys.new
    end

    def ssh_key
      ssh_keys.prefered_key
    end

    def delete_credentials
      File.delete(credentials_path) if credentials_exists?
    end

    def self.guess_email
      @@guess_email ||= IO.popen("git config --get user.email").read.strip
    end

    def config_dir
      File.expand_path("~/.shelly")
    end

    protected
      def credentials_path
        File.join(config_dir, "credentials")
      end

      def credentials_exists?
        File.exists?(credentials_path)
      end
    end
end

