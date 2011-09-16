require "spec_helper"
require "shelly/cli/main"

describe Shelly::CLI::Main do
  before do
    @main = Shelly::CLI::Main.new
    $stdout.stub(:puts)
    $stdout.stub(:print)
  end

  describe "#version" do
    it "should return shelly's version" do
      $stdout.should_receive(:puts).with("shelly version #{Shelly::VERSION}")
      @main.version
    end
  end

  describe "#register" do
    it "should invoke account:register command" do
      @main.should_receive(:invoke).with('account:register')
      @main.register
    end
  end
end
