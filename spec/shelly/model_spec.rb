require "spec_helper"

describe Shelly::Model do
  before do
    config_dir = File.expand_path("~/.shelly")
    FileUtils.mkdir_p(config_dir)
  end

  describe "#current_user" do
    it "should return a user" do
      base = Shelly::Model.new
      user = base.current_user
      user.should be_a(Shelly::User)
    end
  end
end
