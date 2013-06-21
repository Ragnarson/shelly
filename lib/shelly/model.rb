module Shelly
  class Model
    def current_user
      @current_user ||= User.new
    end

    def shelly
      @shelly ||= Client.new
    end
  end
end
