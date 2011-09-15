module Shelly
  module Helpers
    def echo_off
      system "stty -echo"
    end

    def echo_on
      system "stty echo"
    end
  end
end
