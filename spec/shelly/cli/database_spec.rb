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
        'service' => {
          'database_name' => 'foo',
          'username' => 'foo',
          'password' => 'secret'
        }
      }
      @app.should_receive(:tunnel_connection).and_return(conn)
      $stdout.should_receive(:puts).with("host:     localhost")
      $stdout.should_receive(:puts).with("port:     9900")
      $stdout.should_receive(:puts).with("database: foo")
      $stdout.should_receive(:puts).with("username: foo")
      $stdout.should_receive(:puts).with("password: secret")
      invoke(@database, :tunnel, "mongodb")
    end

    it "should setup tunnel" do
      conn = {"host" => "localhost", "service" => {"port" => "27010"}}
      @app.should_receive(:tunnel_connection).and_return(conn)
      @app.should_receive(:setup_tunnel).with(conn, 10103)
      @database.options = {:port => 10103}
      invoke(@database, :tunnel, "mongodb")
    end

    context "on 404 response from API" do
      it "should display error" do
        ex = Shelly::Client::NotFoundException.new({"message" => "Virtual server not found"})
        @app.should_receive(:tunnel_connection).and_raise(ex)
        $stdout.should_receive(:puts).with(red "Virtual server not found")
        lambda {
          invoke(@database, :tunnel, "mongodb")
        }.should raise_error(SystemExit)
      end
    end

    context "on 409 response from API" do
      it "should display error" do
        ex = Shelly::Client::ConflictException.new({"message" => "Unknown service: postgres"})
        @app.should_receive(:tunnel_connection).and_raise(ex)
        $stdout.should_receive(:puts).with(red "Unknown service: postgres")
        lambda {
          invoke(@database, :tunnel, "mongodb")
        }.should raise_error(SystemExit)
      end
    end
  end
end
