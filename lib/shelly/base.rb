module Shelly
  class Base
    def shelly
      user = User.new
      user.load_credentials
      @shelly ||= Client.new(user.email, user.password)
    end
  end
end
