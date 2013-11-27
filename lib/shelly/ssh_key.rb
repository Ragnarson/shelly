module Shelly
  class SshKey < Model
    attr_reader :path
    def initialize(path)
      @path = File.expand_path(path)
    end

    def exists?
      File.exists?(path)
    end

    def destroy
      shelly.delete_ssh_key(fingerprint) if uploaded?
    end

    def upload
      shelly.add_ssh_key(key)
    end

    def uploaded?
      return false unless exists?
      shelly.ssh_key(fingerprint)
      true
    rescue Shelly::Client::NotFoundException
      false
    end

    def fingerprint
      `ssh-keygen -lf #{path}`.split(" ")[1]
    end

    def key
      File.read(path)
    end
  end
end
