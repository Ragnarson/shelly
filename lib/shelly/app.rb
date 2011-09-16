module Shelly
  class App < Base
    DATABASE_KINDS = %w(postgresql mongodb redis none)
    attr_accessor :purpose, :code_name, :databases

    def add_git_remote
      system("git remote add #{purpose} git@git.shellycloud.com:#{code_name}.git")
    end

    def self.guess_code_name
      File.basename(Dir.pwd)
    end
  end
end
