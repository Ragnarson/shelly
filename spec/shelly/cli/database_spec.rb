require "spec_helper"
require "shelly/cli/database"

describe Shelly::CLI::Database do
  before do
    @database = Shelly::CLI::Database.new
    Shelly::CLI::Database.stub(:new).and_return(@database)
    $stdout.stub(:puts)
    $stdout.stub(:print)
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @client.stub(:authorize!)
    @client.stub(:console)
    @app = mock(:to_s => "foo-staging")
    Shelly::App.stub(:new).and_return(@app)
    File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
  end

  describe "#reset" do
    it "should ensure user has logged in" do
      hooks(@database, :reset).should include(:logged_in?)
    end

    it "should reset given database via SSH" do
      $stdout.should_receive(:puts).with("You are about to reset database Mongodb for cloud foo-staging")
      $stdout.should_receive(:puts).with("All database objects and data will be removed")
      @app.should_receive(:reset_database).with("Mongodb")
      fake_stdin(["yes"]) do
        invoke(@database, :reset, "Mongodb")
      end
    end
  end
end
