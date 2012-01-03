require "spec_helper"
require "shelly/cli/runner"

describe Shelly::CLI::Runner do
  before do
    ENV['SHELLY_DEBUG'] = "false"
    @runner = Shelly::CLI::Runner.new(%w(version --debug))
  end

  describe "#initialize" do
    it "should initialize parent class" do
      @runner.should be_kind_of(Thor::Shell::Basic)
      @runner.should respond_to(:say) # if responds to parent class method
    end

    it "should assign args" do
      @runner.args.should == %w(version --debug)
    end
  end

  describe "#debug?" do
    it "should be true if args include --debug option" do
      @runner.should be_debug
    end
    
    it "should be true if SHELLY_DEBUG is set to true" do
      runner = Shelly::CLI::Runner.new
      runner.should_not be_debug
      ENV['SHELLY_DEBUG'] = "true"
      runner.should be_debug
    end

    it "should be false if args doesn't include --debug option" do
      runner = Shelly::CLI::Runner.new(%w(version))
      runner.should_not be_debug
    end
  end

  describe "#start" do
    it "should start main CLI with given args" do
      Shelly::CLI::Main.should_receive(:start).with(%w(version --debug))
      @runner.start
    end

    context "with --debug option (debug mode)" do
      it "should re-raise caught exception to the console" do
        Shelly::CLI::Main.stub(:start).and_raise(RuntimeError.new)
        lambda {
          @runner.start
        }.should raise_error(RuntimeError)
      end
    end

    context "without --debug option (normal mode)" do
      it "should rescue exception and display generic error message" do
        Shelly::CLI::Main.stub(:start).and_raise(RuntimeError.new)
        runner = Shelly::CLI::Runner.new(%w(version))
        $stdout.should_receive(:puts).with("Unknown error, to see debug information run command with --debug")
        lambda {
          runner.start
        }.should raise_error(SystemExit)
      end
    end
  end
end
