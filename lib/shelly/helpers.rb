module Shelly
  module Helpers
    def echo_disabled
      system "stty -echo"
      value = yield
      system "stty echo"
      value
    end

    def say_new_line
      say "\n"
    end

    def say_error(message, options = {})
      options = {:with_exit => true}.merge(options)
      say "\033[91m " + message + " \033[0m"
      return exit 1 if options[:with_exit]
    end
  end
end
