module Shelly
  class App < Base
    attr_accessor :purpose, :code_name, :databases

    def self.guess_code_name
      File.basename(Dir.pwd)
    end
  end
end
