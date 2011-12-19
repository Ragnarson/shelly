require "spec_helper"
require "shelly/cli/deploys"

describe Shelly::CLI::Deploys do
  before do
    FileUtils.stub(:chmod)
    @deploys = Shelly::CLI::Deploys.new
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

    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with("\e[31mNo Cloudfile found\e[0m")
      lambda {
        @deploys.list
      }.should raise_error(SystemExit)
    end

    it "should exit if user doesn't have access to cloud in Cloudfile" do
      response = {"message" => "Cloud foo-staging not found"}
      exception = Shelly::Client::APIError.new(response.to_json)
      @client.stub(:cloud_logs).and_raise(exception)
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-staging' cloud defined in Cloudfile")
      lambda { @deploys.list }.should raise_error(SystemExit)
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show information to select specific cloud and exit" do
        $stdout.should_receive(:puts).with("You have multiple clouds in Cloudfile. Select cloud to view deploy logs using:")
        $stdout.should_receive(:puts).with("  shelly deploys list foo-production")
        $stdout.should_receive(:puts).with("Available clouds:")
        $stdout.should_receive(:puts).with(" * foo-production")
        $stdout.should_receive(:puts).with(" * foo-staging")
        lambda { @deploys.list }.should raise_error(SystemExit)
      end

      it "should take cloud from command line for which to show logs" do
        @client.should_receive(:cloud_logs).with("foo-staging").and_return([{"failed" => false, "created_at" => "2011-12-12-14-14-59"}])
        $stdout.should_receive(:puts).with(green "Available deploy logs")
        $stdout.should_receive(:puts).with(" * 2011-12-12-14-14-59")
        @deploys.list("foo-staging")
      end
    end

    context "single cloud" do
      it "should display available logs" do
        @client.should_receive(:cloud_logs).with("foo-staging").and_return([{"failed" => false, "created_at" => "2011-12-12-14-14-59"}, {"failed" => true, "created_at" => "2011-12-12-15-14-59"}])
        $stdout.should_receive(:puts).with(green "Available deploy logs")
        $stdout.should_receive(:puts).with(" * 2011-12-12-14-14-59")
        $stdout.should_receive(:puts).with(" * 2011-12-12-15-14-59 (failed)")
        @deploys.list
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

    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with("\e[31mNo Cloudfile found\e[0m")
      lambda {
        @deploys.show
      }.should raise_error(SystemExit)
    end

    it "should exit if user doesn't have access to cloud in Cloudfile" do
      response = {"message" => "Cloud foo-staging not found"}
      exception = Shelly::Client::APIError.new(response.to_json)
      @client.stub(:cloud_log).and_raise(exception)
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-staging' cloud defined in Cloudfile")
      lambda { @deploys.show("last") }.should raise_error(SystemExit)
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show information to select specific cloud and exit" do
        $stdout.should_receive(:puts).with("You have multiple clouds in Cloudfile. Select log and cloud to view deploy logs using:")
        $stdout.should_receive(:puts).with("  shelly deploys show last foo-production")
        $stdout.should_receive(:puts).with("Available clouds:")
        $stdout.should_receive(:puts).with(" * foo-production")
        $stdout.should_receive(:puts).with(" * foo-staging")
        lambda { @deploys.show("last") }.should raise_error(SystemExit)
      end

      it "should render the logs" do
        @client.should_receive(:cloud_log).with("foo-staging", "last").and_return(response)
        expected_output
        @deploys.show("last", "foo-staging")
      end
    end

    context "single cloud" do
      it "should render logs without passing cloud" do
        @client.should_receive(:cloud_log).with("foo-staging", "last").and_return(response)
        expected_output
        @deploys.show("last")
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
