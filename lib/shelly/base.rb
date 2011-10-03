require "yaml"

module Shelly
  class Base
    def current_user
      @user = User.new
      @user.load_credentials
      @user
    end

    def config
      @config ||= if File.exists?(config_file_path)
        YAML::load(File.read(config_file_path))
      else
        {}
      end
    end

    def config_file_path
      File.join(current_user.config_dir, "config.yml")
    end

    def shelly
      @shelly ||= Client.new(current_user.email, current_user.password, config)
    end
  end
end
