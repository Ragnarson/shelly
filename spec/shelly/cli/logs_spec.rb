require "spec_helper"
require "shelly/cli/logs"

describe Shelly::CLI::Logs do
  before do
    @cli_logs = Shelly::CLI::Logs.new
    Shelly::CLI::Logs.stub(:new).and_return(@cli_logs)
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @client.stub(:token).and_return("abc")
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @app = Shelly::App.new("foo-production")
    Shelly::App.stub(:new).and_return(@app)
    File.open("Cloudfile", 'w') { |f| f.write("foo-production:\n") }
    $stdout.stub(:puts)
    $stdout.stub(:print)
    @sample_logs = {"entries" => [['app1', 'log1'], ['app1', 'log2']]}
  end

  describe "#latest" do
    it "should ensure user has logged in" do
      hooks(@cli_logs, :latest).should include(:logged_in?)
    end

    it "should ensure multiple_clouds check" do
      @client.stub(:application_logs).and_return(@sample_logs)
      @cli_logs.should_receive(:multiple_clouds).and_return(@app)
      invoke(@cli_logs, :latest)
    end

    it "should exit if user requested too many log lines" do
      exception = Shelly::Client::APIException.new({}, 416)
      @client.stub(:application_logs).and_raise(exception)
      $stdout.should_receive(:puts).
        with(red "You have requested too many log messages. Try a lower number.")
      lambda { invoke(@cli_logs, :latest) }.should raise_error(SystemExit)
    end

    it "should show logs for the cloud" do
      @client.stub(:application_logs).and_return(@sample_logs)
      $stdout.should_receive(:puts).with("app1 log1")
      $stdout.should_receive(:puts).with("app1 log2")
      invoke(@cli_logs, :latest)
    end

    it "should show requested amount of logs" do
      @client.should_receive(:application_logs).
        with("foo-production", {:limit => 2, :source => 'nginx'}).and_return(@sample_logs)
      @cli_logs.options = {:limit => 2, :source => 'nginx'}
      invoke(@cli_logs, :latest)
    end

    it "should show logs since 2013-05-07" do
      @client.should_receive(:application_logs).
        with("foo-production", {:from => '2013-05-07', :source => 'nginx', :limit => 2}).
        and_return(@sample_logs)
      @cli_logs.options = {:from => '2013-05-07', :source => 'nginx', :limit => 2}
      invoke(@cli_logs, :latest)
    end
  end

  describe "#date" do
    it "should ensure user has logged in" do
      hooks(@cli_logs, :date).should include(:logged_in?)
    end

    it "should ensure multiple_clouds check" do
      @client.stub(:application_logs).and_return(@sample_logs)
      @cli_logs.should_receive(:multiple_clouds).and_return(@app)
      invoke(@cli_logs, :date)
    end

    it "should show logs for 2013-05-07" do
      @client.should_receive(:application_logs).
        with("foo-production", {:date => '2013-05-07', :source => nil}).
        and_return(@sample_logs)
      $stdout.should_receive(:puts).with("app1 log1")
      $stdout.should_receive(:puts).with("app1 log2")
      invoke(@cli_logs, :date, '2013-05-07')
    end
  end
end
