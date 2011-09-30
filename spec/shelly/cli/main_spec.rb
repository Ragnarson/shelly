require "spec_helper"
require "shelly/cli/main"

describe Shelly::CLI::Main do
  before do
    @main = Shelly::CLI::Main.new
  end

  describe "#version" do
    it "should return shelly's version" do
      $stdout.should_receive(:puts).with("shelly version #{Shelly::VERSION}")
      @main.version
    end
  end

  describe "#register" do
    it "should invoke account:register command" do
      @main.should_receive(:invoke).with("account:register", "kate@example.com")
      @main.register("kate@example.com")
    end
  end

  describe "#add" do
    it "should invoke apps:add command" do
      @main.should_receive(:invoke).with("apps:add")
      @main.add
    end
  end

  describe "#help" do
    it "should display available commands" do
      expected = <<-OUT
Tasks:
  shelly account <command>  # Manages your account
  shelly add                # Adds new application to Shelly Cloud
  shelly apps <command>     # Manages your applications
  shelly help [TASK]        # Describe available tasks or one specific task
  shelly register [EMAIL]   # Registers new user account on Shelly Cloud
  shelly version            # Displays shelly version
OUT
      out = IO.popen("bin/shelly").read.strip
      out.should == expected.strip
    end
  end
end
