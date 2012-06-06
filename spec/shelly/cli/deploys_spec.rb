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
    @app = Shelly::App.new("foo-staging")
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

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.should_receive(:deploy_logs).with("foo-staging").and_return([
        {"failed" => false, "created_at" => "2011-12-12-14-14-59"}])
      @deploys.should_receive(:multiple_clouds).and_return(@app)
      invoke(@deploys, :list)
    end

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

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.should_receive(:deploy_log).with("foo-staging", "last").and_return(response)
      @deploys.should_receive(:multiple_clouds).and_return(@app)
      invoke(@deploys, :show, "last")
    end

    context "log not found" do
      it "should exit 1 with message" do
        exception = Shelly::Client::NotFoundException.new("resource" => "log")
        @client.stub(:deploy_log).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Log not found, list all deploy logs using `shelly deploys list --cloud=foo-staging`")
        lambda { @deploys.show("last") }.should raise_error(SystemExit)
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
