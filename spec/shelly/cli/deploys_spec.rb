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
        $stdout.should_receive(:puts).with("  shelly deploy list foo-production")
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

end