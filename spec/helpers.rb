module RSpec
  module Helpers
    def lib
      File.expand_path("../../lib")
    end

    def executable
      File.expand_path("bin/shelly")
    end

    def shelly(cmd)
      cmd = "ruby -I#{lib} #{executable} #{cmd}"
      IO.popen(cmd).gets.strip
    end
  end
end
