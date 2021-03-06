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
      runner.should_receive(:system).with("gem install shelly")
      $stdout.should_receive(:puts).with("Required shelly gem version: 0.0.48")
      $stdout.should_receive(:puts).with("Your version: #{Shelly::VERSION}")
      $stdout.should_receive(:print).with("Update shelly gem? ")
      fake_stdin(["yes"]) do
        runner.start
      end
    end

    describe "windows development" do
      it "should show warning message" do
        Gem.stub(:win_platform?).and_return(true)
        $stdout.should_receive(:puts).with("shelly gem does not support Windows. More info at:")
        $stdout.should_receive(:puts).with("https://shellycloud.com/documentation/faq#windows")
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:puts).with("shelly version #{Shelly::VERSION}")

        Shelly::CLI::Runner.new(%w(version --debug)).start
      end
    end

    describe "API exception handling" do
      before do
        @client = mock
        Shelly::Client.stub(:new).and_return(@client)
        @client.stub(:authorize!).and_return(true)
        @runner = Shelly::CLI::Runner.new(%w(status))
      end

      it "should rescue unauthorized exception and display message" do
        @client.stub(:apps).and_raise(Shelly::Client::UnauthorizedException.new)
        $stdout.should_receive(:puts).with("You are not logged in. To log in use: `shelly login`")
        lambda {
          @runner.start
        }.should raise_error(SystemExit)
      end

      it "should rescue not found exception for cloud" do
        exception = Shelly::Client::NotFoundException.new({"resource" => "cloud", "id" => "foooo"}, 404)
        @client.stub(:apps).and_raise(exception)
        $stdout.should_receive(:puts).with("You have no access to 'foooo' cloud")
        lambda {
          @runner.start
        }.should raise_error(SystemExit)
      end

      it "should re-raise not found exception for non cloud" do
        exception = Shelly::Client::NotFoundException.new({"resource" => "config"}, 404)
        @client.stub(:apps).and_raise(exception)
        lambda {
          @runner.start
        }.should raise_error(Shelly::Client::NotFoundException)
      end
    end

    context "with --debug option (debug mode)" do
      it "should re-raise caught exception to the console" do
        Shelly::CLI::Main.stub(:start).and_raise(RuntimeError.new)
        lambda {
          @runner.start
        }.should raise_error(RuntimeError)
      end

      it "should re-raise netrc exception" do
        Shelly::CLI::Main.stub(:start).and_raise(Netrc::Error.new)
        lambda {
          @runner.start
        }.should raise_error(Netrc::Error)
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

      it "should rescue netrc exception and display message" do
        Shelly::CLI::Main.stub(:start).and_raise(Netrc::Error.new("Error"))
        runner = Shelly::CLI::Runner.new(%w(start))
        $stdout.should_receive(:puts).with("Error")
        lambda {
          runner.start
        }.should raise_error(SystemExit)
      end

      it "should catch exception thrown by API Client" do
        Shelly::CLI::Main.stub(:start).and_raise(Shelly::Client::APIException.new({}, 500, "test123"))
        runner = Shelly::CLI::Runner.new(%w(version))
        $stdout.should_receive(:puts).with("You have found a bug in the shelly gem. We're sorry.")
        $stdout.should_receive(:puts).with(<<-eos
You can report it to support@shellycloud.com by describing what you wanted
to do and mentioning error id test123.
        eos
        )
        lambda {
          runner.start
        }.should raise_error(SystemExit)
      end

      it "should not print reporting info if no request id returned" do
        Shelly::CLI::Main.stub(:start).and_raise(Shelly::Client::APIException.new({}, 500, nil))
        runner = Shelly::CLI::Runner.new(%w(version))
        $stdout.should_receive(:puts).with("You have found a bug in the shelly gem. We're sorry.")
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
