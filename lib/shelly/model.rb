module Shelly
  class Model
    def current_user
      @user = User.new
      @user.load_credentials
      @user
    end

    def shelly
      @shelly ||= Client.new(current_user.email, current_user.password)
    end
  end
end
