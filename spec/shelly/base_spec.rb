require "spec_helper"

describe Shelly::Base do
  before do
    config_dir = File.expand_path("~/.shelly")
    FileUtils.mkdir_p(config_dir)
  end

  describe "#current_user" do
    it "should return user with loaded credentials" do
      File.open(File.join("~/.shelly/credentials"), "w") { |f| f << "superman@example.com\nthe-kal-el" }
      base = Shelly::Base.new
      user = base.current_user
      user.email.should == "superman@example.com"
      user.password.should == "the-kal-el"
    end
  end

  describe "#config" do
    context "config file exists" do
      it "should return loaded config as a Hash" do
        File.open("~/.shelly/config.yml", "w") { |f| f << "shelly_url: http://api.example.com/v4/\n" }
        base = Shelly::Base.new
        base.config.should == {"shelly_url" => "http://api.example.com/v4/"}
      end
    end

    context "config file doesn't exist" do
      it "should return an empty Hash" do
        base = Shelly::Base.new
        base.config.should == {}
      end
    end
  end
end
