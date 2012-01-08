require "spec_helper"
require "shelly/cli/deploys"

describe Shelly::CLI::Deploys do
  before do
    FileUtils.stub(:chmod)
    @deploys = Shelly::CLI::Deploys.new
    Shelly::CLI::Deploys.stub(:new).and_return(@deploys)
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    $stdout.stub(:puts)
    $stdout.stub(:print)
  end

  describe "#list" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
      @client.stub(:token).and_return("abc")
    end

    it "should ensure user has logged in" do
      hooks(@deploys, :list).should include(:logged_in?)
    end

    it "should ensure that Cloudfile is present" do
      hooks(@deploys, :list).should include(:cloudfile_present?)
    end

    it "should exit if user doesn't have access to cloud in Cloudfile" do
      @client.stub(:deploy_logs).and_raise(Shelly::Client::NotFoundException.new("resource" => "cloud"))
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-staging' cloud defined in Cloudfile")
      lambda { invoke(@deploys, :list) }.should raise_error(SystemExit)
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show information to select specific cloud and exit" do
        $stdout.should_receive(:puts).with(red "You have multiple clouds in Cloudfile.")
        $stdout.should_receive(:puts).with("Select cloud using `shelly deploys list --cloud foo-production`")
        $stdout.should_receive(:puts).with("Available clouds:")
        $stdout.should_receive(:puts).with(" * foo-production")
        $stdout.should_receive(:puts).with(" * foo-staging")
        lambda { invoke(@deploys, :list) }.should raise_error(SystemExit)
      end

      it "should take cloud from command line for which to show logs" do
        @client.should_receive(:deploy_logs).with("foo-staging").and_return([{"failed" => false, "created_at" => "2011-12-12-14-14-59"}])
        $stdout.should_receive(:puts).with(green "Available deploy logs")
        $stdout.should_receive(:puts).with(" * 2011-12-12-14-14-59")
        @deploys.options = {:cloud => "foo-staging"}
        invoke(@deploys, :list)
      end
    end

    context "single cloud" do
      it "should display available logs" do
        @client.should_receive(:deploy_logs).with("foo-staging").and_return([
          {"failed" => false, "created_at" => "2011-12-12-14-14-59"},
          {"failed" => true, "created_at" => "2011-12-12-15-14-59"}])
        $stdout.should_receive(:puts).with(green "Available deploy logs")
        $stdout.should_receive(:puts).with(" * 2011-12-12-14-14-59")
        $stdout.should_receive(:puts).with(" * 2011-12-12-15-14-59 (failed)")
        invoke(@deploys, :list)
      end
    end
  end

  describe "#show" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
      @client.stub(:token).and_return("abc")
    end

    it "should ensure user has logged in" do
      hooks(@deploys, :show).should include(:logged_in?)
    end

    it "should ensure that Cloudfile is present" do
      hooks(@deploys, :show).should include(:cloudfile_present?)
    end

    context "user doesn't have access to cloud" do
      it "should exit 1 with message" do
        exception = Shelly::Client::NotFoundException.new("resource" => "cloud")
        @client.stub(:deploy_log).and_raise(exception)
        $stdout.should_receive(:puts).with(red "You have no access to 'foo-staging' cloud defined in Cloudfile")
        lambda { @deploys.show("last") }.should raise_error(SystemExit)
      end
    end

    context "log not found" do
      it "should exit 1 with message" do
        exception = Shelly::Client::NotFoundException.new("resource" => "log")
        @client.stub(:deploy_log).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Log not found, list all deploy logs using  `shelly deploys list --cloud=foo-staging`")
        lambda { @deploys.show("last") }.should raise_error(SystemExit)
      end
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show information to select specific cloud and exit" do
        $stdout.should_receive(:puts).with(red "You have multiple clouds in Cloudfile.")
        $stdout.should_receive(:puts).with("Select cloud using `shelly deploys show last --cloud foo-production`")
        $stdout.should_receive(:puts).with("Available clouds:")
        $stdout.should_receive(:puts).with(" * foo-production")
        $stdout.should_receive(:puts).with(" * foo-staging")
        lambda { invoke(@deploys, :show, "last") }.should raise_error(SystemExit)
      end

      it "should render the logs" do
        @client.should_receive(:deploy_log).with("foo-staging", "last").and_return(response)
        expected_output
        @deploys.options = {:cloud => "foo-staging"}
        invoke(@deploys, :show, "last")
      end
    end

    context "single cloud" do
      it "should render logs without passing cloud" do
        @client.should_receive(:deploy_log).with("foo-staging", "last").and_return(response)
        expected_output
        invoke(@deploys, :show, "last")
      end
    end

    def expected_output
      $stdout.should_receive(:puts).with(green "Log for deploy done on 2011-12-12 at 14:14:59")
      $stdout.should_receive(:puts).with(green "Starting bundle install")
      $stdout.should_receive(:puts).with("Installing gems")
      $stdout.should_receive(:puts).with(green "Starting whenever")
      $stdout.should_receive(:puts).with("Looking up schedule.rb")
      $stdout.should_receive(:puts).with(green "Starting callbacks")
      $stdout.should_receive(:puts).with("rake db:migrate")
      $stdout.should_receive(:puts).with(green "Starting delayed job")
      $stdout.should_receive(:puts).with("delayed jobs")
      $stdout.should_receive(:puts).with(green "Starting thin")
      $stdout.should_receive(:puts).with("thins up and running")
    end

    def response
      {"created_at" => "2011-12-12 at 14:14:59", "bundle_install" => "Installing gems",
        "whenever" => "Looking up schedule.rb", "thin_restart" => "thins up and running",
        "delayed_job" => "delayed jobs", "callbacks" => "rake db:migrate"}
    end

  end

end
