require 'erb'

module Shelly
  class App < Base
    DATABASE_KINDS = %w(postgresql mongodb redis none)
    attr_accessor :purpose, :code_name, :databases

    def add_git_remote
      system("git remote add #{purpose} git@git.shellycloud.com:#{code_name}.git")
    end

    def generate_cloudfile
      @email = current_user.email
      @databases = databases
      template = File.read("lib/shelly/templates/Cloudfile.erb")
      cloudfile = ERB.new(template, 0, "%<>")
      cloudfile.result(binding)
    end

    def self.guess_code_name
      File.basename(Dir.pwd)
    end
  end
end
