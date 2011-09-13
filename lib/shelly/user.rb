module Shelly
  class User
    attr_reader :email, :password
    def initialize(email = nil, password = nil)
      @email = email
      @password = password
    end

    def register
      client = Client.new
      client.register_user(email, password)
      save_credentials
    end

    def self.guess_email
      @@guess_email ||= IO.popen("git config --get user.email").read.strip
    end

    def load_credentials
      @email, @password = File.read(credentials_path).split("\n")
    end

    def save_credentials
      FileUtils.mkdir_p(config_dir) unless credentials_exists?
      File.open(credentials_path, 'w') { |file| file << "#{email}\n#{password}" }
      set_credentials_permissions
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
