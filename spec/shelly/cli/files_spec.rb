require "spec_helper"
require "shelly/cli/files"

describe Shelly::CLI::Files do
  before do
    FileUtils.stub(:chmod)
    @cli_files = Shelly::CLI::Files.new
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @client.stub(:token).and_return("abc")
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @app = Shelly::App.new("foo-staging")
    Shelly::App.stub(:new).and_return(@app)
    File.open("Cloudfile", 'w') { |f| f.write("foo-production:\n") }
  end

  describe "#upload" do
    it "should ensure user has logged in" do
      hooks(@cli_files, :upload).should include(:logged_in?)
    end

    it "should upload files" do
      expected = {"host" => "console.example.com", "port" => "40010", "user" => "foo"}
      @client.stub(:console).and_return(expected)
      @app.should_receive(:upload).with("some/path")
      invoke(@cli_files, :upload, "some/path")
    end

    it "should exit if rsync isn't installed" do
      FakeFS::File.stub(:executable?).and_return(false)
      $stdout.should_receive(:puts).with(red "You need to install rsync in order to upload and download files")
      lambda { invoke(@cli_files, :upload, "some/path") }.should raise_error(SystemExit)
    end

    context "cloud is not running" do
      it "should display error" do
        @client.stub(:console).and_raise(Shelly::Client::ConflictException)
        $stdout.should_receive(:puts).with(red "Cloud foo-production is not running. Cannot upload files.")
        lambda {
          invoke(@cli_files, :upload, "some/path")
        }.should raise_error(SystemExit)
      end
    end
  end

  describe "#download" do
    it "should ensure user has logged in" do
      hooks(@cli_files, :download).should include(:logged_in?)
    end

    it "should exit if rsync isn't installed" do
      FakeFS::File.stub(:executable?).and_return(false)
      $stdout.should_receive(:puts).with(red "You need to install rsync in order to upload and download files")
      lambda { invoke(@cli_files, :download, "some/path") }.should raise_error(SystemExit)
    end

    it "should download files" do
      expected = {"host" => "console.example.com", "port" => "40010", "user" => "foo"}
      @client.stub(:console).and_return(expected)
      @app.should_receive(:download).with("some/path", "/destination")
      invoke(@cli_files, :download, "some/path", "/destination")
    end
  end
end
