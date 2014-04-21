require "spec_helper"
require "shelly/cli/logs"
require "shelly/download_progress_bar"

describe Shelly::CLI::Logs do
  before do
    @cli_logs = Shelly::CLI::Logs.new
    Shelly::CLI::Logs.stub(:new).and_return(@cli_logs)
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @client.stub(:authorize!)
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @app = Shelly::App.new("foo-production")
    Shelly::App.stub(:new).and_return(@app)
    File.open("Cloudfile", 'w') { |f| f.write("foo-production:\n") }
    $stdout.stub(:puts)
    $stdout.stub(:print)
  end

  describe "#latest" do
    before do
      @sample_logs = {"entries" => [['app1', 'log1'], ['app1', 'log2']]}
    end

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

  describe "#get" do
    before do
      @bar = mock(:progress_callback => @callback, :finish => true)
      Shelly::DownloadProgressBar.stub(:new).and_return(@bar)
      @client.stub(:download_application_logs_attributes).
        with("foo-production", {:date => "2013-05-31"}).
        and_return({"filename" => "foo-production.log.20130531.gz",
                   "url" => "http://example.com/foo-production/20130531",
                   "size" => 12345})
      $stdout.stub(:puts)
    end

    it "should ensure user has logged in" do
      hooks(@cli_logs, :get).should include(:logged_in?)
    end

    it "should ensure multiple_clouds check" do
      @client.stub(:download_file).
        with("foo-production", "foo-production.log.20130531.gz",
             "http://example.com/foo-production/20130531", @callback)
      @cli_logs.should_receive(:multiple_clouds).and_return(@app)
      invoke(@cli_logs, :get, "2013-05-31")
    end

    it "should have a 'download' alias" do
      @client.should_receive(:download_file).
        with("foo-production", "foo-production.log.20130531.gz",
             "http://example.com/foo-production/20130531", @callback)
      invoke(@cli_logs, :download, "2013-05-31")
    end


    it "should fetch filename, url and size and initialize download progress bar" do
      @client.should_receive(:download_file).
        with("foo-production", "foo-production.log.20130531.gz",
             "http://example.com/foo-production/20130531", @callback)
      Shelly::DownloadProgressBar.should_receive(:new).and_return(@bar)
      invoke(@cli_logs, :get, "2013-05-31")
    end

    it "should fetch given log file itself" do
      @client.should_receive(:download_file).
        with("foo-production", "foo-production.log.20130531.gz",
             "http://example.com/foo-production/20130531",
             @callback)
      invoke(@cli_logs, :get, "2013-05-31")
    end

    it "should show info where file has been saved" do
      $stdout.should_receive(:puts)
      $stdout.should_receive(:puts).with(green "Log file saved to foo-production.log.20130531.gz")
      @client.should_receive(:download_file).
        with("foo-production", "foo-production.log.20130531.gz",
             "http://example.com/foo-production/20130531",
             @callback)
      invoke(@cli_logs, :get, "2013-05-31")
    end

    context "on log file not found" do
      it "should display error message" do
        exception = RestClient::ResourceNotFound.new
        @client.stub(:download_file).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Log file not found")
        invoke(@cli_logs, :get, "2013-05-31")
      end
    end

    context "on invalid date format" do
      it "should display error message" do
        exception = Shelly::Client::ValidationException.new({
          "errors" => [["Date", "format is invalid"]]})
        @client.stub(:download_file).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Date format is invalid")
        invoke(@cli_logs, :get, "2013-05-31")
      end
    end
  end
end
