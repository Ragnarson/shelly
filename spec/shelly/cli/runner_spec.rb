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

    it "should rescue interrupt exception and display message" do
      Shelly::CLI::Main.stub(:start).and_raise(Interrupt.new)
      runner = Shelly::CLI::Runner.new(%w(login))
      $stdout.should_receive(:puts).with("\n")
      $stdout.should_receive(:puts).with("[canceled]")
      lambda {
        runner.start
      }.should raise_error(SystemExit)
    end

    it "should rescue gem version exception and display message" do
      Shelly::CLI::Main.stub(:start).and_raise(Shelly::Client::GemVersionException.new(
        {"required_version" => "0.0.48"}))
      runner = Shelly::CLI::Runner.new(%w(login))
      $stdout.should_receive(:puts).with("Required shelly gem version: 0.0.48")
      $stdout.should_receive(:puts).with("Your version: #{Shelly::VERSION}")
      $stdout.should_receive(:puts).with("Update shelly gem with `gem install shelly`")
      $stdout.should_receive(:puts).with("or `bundle update shelly` when using bundler")
      lambda {
        runner.start
      }.should raise_error(SystemExit)
    end

    it "should rescue unauthorized exception and display message" do
      @client = mock
      runner = Shelly::CLI::Runner.new(%w(status))
      Shelly::Client.stub(:new).and_return(@client)
      @client.stub(:token).and_return("abc")
      @client.stub(:apps).and_raise(Shelly::Client::UnauthorizedException.new)
      $stdout.should_receive(:puts).with("You are not logged in. To log in use: `shelly login`")
      lambda {
        runner.start
      }.should raise_error(SystemExit)
    end

    context "with --debug option (debug mode)" do
      it "should re-raise caught exception to the console" do
        Shelly::CLI::Main.stub(:start).and_raise(RuntimeError.new)
        lambda {
          @runner.start
        }.should raise_error(RuntimeError)
      end

      it "should re-raise unauthorized exception" do
        Shelly::CLI::Main.stub(:start).and_raise(Shelly::Client::UnauthorizedException.new)
        lambda {
          @runner.start
        }.should raise_error(Shelly::Client::UnauthorizedException)
      end

      it "should re-raise gem version exception" do
        Shelly::CLI::Main.stub(:start).and_raise(Shelly::Client::GemVersionException.new)
        lambda {
          @runner.start
        }.should raise_error(Shelly::Client::GemVersionException)
      end

      it "should re-raise interupt exception" do
        Shelly::CLI::Main.stub(:start).and_raise(Interrupt.new)
        lambda {
          @runner.start
        }.should raise_error(Interrupt)
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

      it "should catch exception thrown by API Client" do
        Shelly::CLI::Main.stub(:start).and_raise(Shelly::Client::APIException.new)
        runner = Shelly::CLI::Runner.new(%w(version))
        $stdout.should_receive(:puts).with("Unknown error, to see debug information run command with --debug")
        lambda {
          runner.start
        }.should raise_error(SystemExit)
      end

      it "should re-reise SystemExit exceptions" do
        Shelly::CLI::Main.stub(:start).and_raise(SystemExit.new)
        $stdout.should_not_receive(:puts).with("Unknown error, to see debug information run command with --debug")
        runner = Shelly::CLI::Runner.new(%w(version))
        lambda {
          runner.start
        }.should raise_error(SystemExit)
      end
    end
  end
end
