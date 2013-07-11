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

  describe "#tunnel" do
    it "should ensure user has logged in" do
      hooks(@database, :tunnel).should include(:logged_in?)
    end

    it "should show tunnel's details" do
      @app.stub(:setup_tunnel)
      conn = {
        'user' => 'foo',
        'password' => 'secret',
        'port' => '9900',
        'database name' => 'foo'
      }
      @app.should_receive(:tunnel_connection).and_return(conn)
      $stdout.should_receive(:puts).with("host:          localhost")
      $stdout.should_receive(:puts).with("port:          9900")
      $stdout.should_receive(:puts).with("database name: foo")
      $stdout.should_receive(:puts).with("username:      foo")
      $stdout.should_receive(:puts).with("password:      secret")
      invoke(@database, :tunnel, "mongodb")
    end

    it "should setup tunnel" do
      @app.should_receive(:tunnel_connection).and_return({"host" => "localhost"})
      @app.should_receive(:setup_tunnel).with({"host" => "localhost"}, 10103)
      @database.options = {:port => 10103}
      invoke(@database, :tunnel, "mongodb")
    end
  end
end
