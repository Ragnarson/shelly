require "spec_helper"

describe Shelly::Model do
  before do
    config_dir = File.expand_path("~/.shelly")
    FileUtils.mkdir_p(config_dir)
  end

  describe "#current_user" do
    it "should return user with loaded credentials" do
      File.open(File.join("~/.shelly/credentials"), "w") { |f| f << "superman@example.com\nthe-kal-el" }
      base = Shelly::Model.new
      user = base.current_user
      user.email.should == "superman@example.com"
      user.password.should == "the-kal-el"
    end
  end
end
