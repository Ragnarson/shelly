require "spec_helper"
require "shelly/cli/account"

describe Shelly::CLI::Account do
  before do
    FileUtils.stub(:chmod)
    @client = mock
    @account = Shelly::CLI::Account.new
    Shelly::Client.stub(:new).and_return(@client)
    $stdout.stub(:puts)
    $stdout.stub(:print)
  end

  describe "#register" do
    before do
      Shelly::User.stub(:guess_email).and_return("")
      @client.stub(:register_user)
      @key_path = File.expand_path("~/.ssh/id_rsa.pub")
    end

    it "should ask for email, password and password confirmation" do
      $stdout.should_receive(:print).with("Email: ")
      $stdout.should_receive(:print).with("Password: ")
      $stdout.should_receive(:print).with("Password confirmation: ")
      fake_stdin(["better@example.com", "secret", "secret"]) do
        @account.register
      end
    end

    it "should suggest email and use it if user enters blank email" do
      Shelly::User.stub(:guess_email).and_return("kate@example.com")
      $stdout.should_receive(:print).with("Email (kate@example.com - default): ")
      @client.should_receive(:register_user).with("kate@example.com", "secret", nil)
      fake_stdin(["", "secret", "secret"]) do
        @account.register
      end
    end

    it "should use email provided by user" do
      @client.should_receive(:register_user).with("better@example.com", "secret", nil)
      fake_stdin(["better@example.com", "secret", "secret"]) do
        @account.register
      end
    end

    it "should ask for email again if it's blank" do
      Shelly::User.stub(:guess_email).and_return("")
      $stdout.should_receive(:puts).with("Email can't be blank, please type it again")
      fake_stdin(["", "bob@example.com", "only-pass", "only-pass"]) do
        @account.register
      end
    end

    it "should ask for password again if it's blank" do
      $stdout.should_receive(:puts).with("Password can't be blank")
      fake_stdin(["better@example.com", "", "", "secret", "secret"]) do
        @account.register
      end
    end

    it "should ask for password and password confirmation again if they don't match each other" do
      $stdout.should_receive(:puts).with("Password and password confirmation don't match, please type them again")
      fake_stdin(["better@example.com", "secret", "sec-TYPO-ret", "secret", "secret"]) do
        @account.register
      end
    end

    context "ssh key exists" do
      it "should register with ssh-key" do
        FileUtils.mkdir_p("~/.ssh")
        File.open(@key_path, "w") { |f| f << "key" }
        $stdout.should_receive(:puts).with("Uploading your public SSH key from #{@key_path}")
        fake_stdin(["kate@example.com", "secret", "secret"]) do
          @account.register
        end
      end
    end

    context "ssh key doesn't exist" do
      it "should register user without the ssh key" do
        $stdout.should_not_receive(:puts).with("Uploading your public SSH key from #{@key_path}")
        fake_stdin(["kate@example.com", "secret", "secret"]) do
          @account.register
        end
      end
    end

    context "on successful registration" do
      it "should display message about registration and email address confirmation" do
        @client.stub(:register_user).and_return(true)
        $stdout.should_receive(:puts).with("Successfully registered!")
        $stdout.should_receive(:puts).with("Check you mailbox for email address confirmation")
        fake_stdin(["kate@example.com", "pass", "pass"]) do
          @account.register
        end
      end
    end

    context "on unsuccessful registration" do
      it "should display errors" do
        response = {"message" => "Validation Failed", "errors" => [["email", "has been already taken"]]}
        exception = Shelly::Client::APIError.new(response)
        @client.stub(:register_user).and_raise(exception)
        $stdout.should_receive(:puts).with("email has been already taken")
        fake_stdin(["kate@example.com", "pass", "pass"]) do
          @account.register
        end
      end
    end
  end
end