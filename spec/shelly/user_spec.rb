require "shelly/user"
require "spec_helper"

describe Shelly::User do
  include FakeFS::SpecHelpers

  before do
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @user = Shelly::User.new("bob@example.com", "secret")
    @user.stub(:set_credentials_permissions)
  end

  describe ".guess_email" do
    it "should return user email fetched from git config" do
      io = mock(:read => "boby@example.com\n")
      IO.should_receive(:popen).with("git config --get user.email").and_return(io)
      Shelly::User.guess_email.should == "boby@example.com"
    end
  end

  describe "#register" do
    before do
      @client.stub(:register_user)
    end

    it "should register user at Shelly Cloud" do
      @client.should_receive(:register_user).with("bob@example.com", "secret")
      @user.register
    end

    it "should save credentials after successful registration" do
      @user.should_receive(:save_credentials)
      @user.register
    end
  end

  describe "#save_credentials" do
    it "should save credentials to file" do
      File.exists?("~/.shelly/credentials").should be_false
      @user.save_credentials
      File.read("~/.shelly/credentials").should == "bob@example.com\nsecret"
    end

    it "should create config_dir if doesn't exist" do
      File.exists?("~/.shelly").should be_false
      @user.save_credentials
      File.exists?("~/.shelly").should be_true
    end

    it "should set proper permissions on config_dir and credentials file" do
      user = Shelly::User.new("bob@example.com", "secret")
      FileUtils.should_receive(:chmod).with(0700, File.expand_path("~/.shelly"))
      FileUtils.should_receive(:chmod).with(0600, File.expand_path("~/.shelly/credentials"))
      user.save_credentials
    end
  end

  describe "#load_credentials" do
    it "should load credentials from file" do
      config_dir = File.expand_path("~/.shelly")
      FileUtils.mkdir_p(config_dir)
      File.open(File.join(config_dir, "credentials"), "w") { |f| f << "superman@example.com\nkal-el" }
      user = Shelly::User.new
      user.load_credentials
      user.email.should == "superman@example.com"
      user.password.should == "kal-el"
    end
  end
end
