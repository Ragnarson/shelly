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

    def delete_credentials
      File.delete(credentials_path) if credentials_exists?
    end

    def delete_ssh_key
      shelly.delete_ssh_key(File.read(dsa_key)) if File.exists?(dsa_key)
      shelly.delete_ssh_key(File.read(rsa_key)) if File.exists?(rsa_key)
    end

    def ssh_key_exists?
      File.exists?(ssh_key_path)
    end

    def ssh_key_path
      return dsa_key if File.exists?(dsa_key)
      rsa_key
    end

    def dsa_key
      File.expand_path("~/.ssh/id_dsa.pub")
    end

    def rsa_key
      File.expand_path("~/.ssh/id_rsa.pub")
    end

    def self.guess_email
      @@guess_email ||= IO.popen("git config --get user.email").read.strip
    end

    def config_dir
      File.expand_path("~/.shelly")
    end

    def upload_ssh_key
      key = File.read(ssh_key_path).strip
      shelly.add_ssh_key(key)
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

