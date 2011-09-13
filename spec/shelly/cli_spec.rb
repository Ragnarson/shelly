require "spec_helper"
require "shelly/cli"
require "shelly/user"

describe Shelly::CLI do
  before do
    @client = mock
    @cli = Shelly::CLI.new
    Shelly::Client.stub(:new).and_return(@client)
    $stdout.stub(:puts)
    $stdout.stub(:print)
  end

  describe "#version" do
    it "should return shelly's version" do
      $stdout.should_receive(:puts).with("shelly version #{Shelly::VERSION}")
      @cli.version
    end
  end

  describe "#register" do
    before do
      Shelly::User.stub(:guess_email).and_return("")
      @client.stub(:register_user)
    end

    it "should ask for email and password" do
      $stdout.should_receive(:print).with("Email: ")
      $stdout.should_receive(:print).with("Password: ")
      fake_stdin(["better@example.com", "secret"]) do
        @cli.register
      end
    end

    it "should suggest email and use it if user enters blank email" do
      Shelly::User.stub(:guess_email).and_return("kate@example.com")
      $stdout.should_receive(:print).with("Email (default kate@example.com): ")
      @client.should_receive(:register_user).with("kate@example.com", "secret")
      fake_stdin(["", "secret"]) do
        @cli.register
      end
    end

    it "should use email provided by user" do
      @client.should_receive(:register_user).with("better@example.com", "secret")
      fake_stdin(["better@example.com", "secret"]) do
        @cli.register
      end
    end

    it "should exit with message if email is blank" do
      Shelly::User.stub(:guess_email).and_return("")
      $stdout.should_receive(:puts).with("Email and password can't be blank")
      lambda do
        fake_stdin(["", "only-pass"]) do
          @cli.register
        end
      end.should raise_error(SystemExit)
    end

    it "should exit with message if password is blank" do
      $stdout.should_receive(:puts).with("Email and password can't be blank")
      lambda do
        fake_stdin(["better@example.com", ""]) do
          @cli.register
        end
      end.should raise_error(SystemExit)
    end

    context "on successful registration" do
      it "should display message about registration and email confirmation" do
        @client.stub(:register_user).and_return(true)
        $stdout.should_receive(:puts).with("Successfully registered!\nCheck you mailbox for email confirmation")
        fake_stdin(["kate@example.com", "pass"]) do
          @cli.register
        end
      end
    end

    context "on unsuccessful registration" do
      it "should display errors" do
        response = {"message" => "Validation Failed", "errors" => [["email", "has been already taken"]]}
        exception = Shelly::Client::APIError.new(response)
        @client.stub(:register_user).and_raise(exception)
        $stdout.should_receive(:puts).with("email has been already taken")
        fake_stdin(["kate@example.com", "pass"]) do
          @cli.register
        end
      end
    end
  end
end
