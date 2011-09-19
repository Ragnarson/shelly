module Shelly
  class User < Base
    attr_reader :email, :password
    def initialize(email = nil, password = nil)
      @email = email
      @password = password
    end

    def register
      ssh_key = File.read(ssh_key_path) if ssh_key_exists?
      shelly.register_user(email, password, ssh_key)
      save_credentials
    end

    def token
      shelly.token["token"]
    end

    def load_credentials
      return unless credentials_exists?
      @email, @password = File.read(credentials_path).split("\n")
    end

    def save_credentials
      FileUtils.mkdir_p(config_dir) unless credentials_exists?
      File.open(credentials_path, 'w') { |file| file << "#{email}\n#{password}" }
      set_credentials_permissions
    end

    def ssh_key_exists?
      File.exists?(ssh_key_path)
    end

    def ssh_key_path
      File.expand_path("~/.ssh/id_rsa.pub")
    end

    def self.guess_email
      @@guess_email ||= IO.popen("git config --get user.email").read.strip
    end

    protected
      def config_dir
        File.expand_path("~/.shelly")
      end

      def credentials_path
        File.join(config_dir, "credentials")
      end

      def credentials_exists?
        File.exists?(credentials_path)
      end

      def set_credentials_permissions
        FileUtils.chmod(0700, config_dir)
        FileUtils.chmod(0600, credentials_path)
      end
    end
end
