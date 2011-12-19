require "spec_helper"
require "shelly/cli/config"

describe Shelly::CLI::Config do

  before do
    FileUtils.stub(:chmod)
    @config = Shelly::CLI::Config.new
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    $stdout.stub(:puts)
    $stdout.stub(:print)
  end

  describe "#list" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      @client.stub(:token).and_return("abc")
    end

    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with(red "No Cloudfile found")
      lambda {
        @config.list
      }.should raise_error(SystemExit)
    end

    it "should exit if user doesn't have access to cloud in Cloudfile" do
      response = {"message" => "Cloud foo-staging not found"}
      exception = Shelly::Client::APIError.new(response.to_json)
      @client.stub(:app_configs).and_raise(exception)
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
      lambda { @config.list }.should raise_error(SystemExit)
    end

    it "should list available configuration files for clouds" do
      @client.should_receive(:app_configs).with("foo-staging").and_return([{"created_by_user" => true, "path" => "config/settings.yml"}])
      @client.should_receive(:app_configs).with("foo-production").and_return([{"created_by_user" => false, "path" => "config/app.yml"}])
      $stdout.should_receive(:puts).with(green "Configuration files for foo-production")
      $stdout.should_receive(:puts).with("You have no custom configuration files.")
      $stdout.should_receive(:puts).with("Following files are created by Shelly Cloud:")
      $stdout.should_receive(:puts).with(" * config/app.yml")
      $stdout.should_receive(:puts).with(green "Configuration files for foo-staging")
      $stdout.should_receive(:puts).with("Custom configuration files:")
      $stdout.should_receive(:puts).with(" * config/settings.yml")

      @config.list
    end

  end

end