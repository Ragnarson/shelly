module RSpec
  module Helpers
    def fake_stdin(strings)
      InputFaker.with_fake_input(strings) { yield }
    end

    def green(string)
      "\e[32m#{string}\e[0m"
    end

    def red(string)
      "\e[31m#{string}\e[0m"
    end
  end
end
