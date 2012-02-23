require "spec_helper"
require "shelly/cli/user"

describe Shelly::CLI::User do
  before do
    FileUtils.stub(:chmod)
    @cli_user = Shelly::CLI::User.new
    Shelly::CLI::User.stub(:new).and_return(@cli_user)
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    Shelly::User.stub(:guess_email).and_return("")
    $stdout.stub(:puts)
    $stdout.stub(:print)
    @client.stub(:token).and_return("abc")
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
  end

  describe "#help" do
    it "should show help" do
      $stdout.should_receive(:puts).with("Tasks:")
      $stdout.should_receive(:puts).with(/add \[EMAIL\]\s+# Add new developer to clouds defined in Cloudfile/)
        $stdout.should_receive(:puts).with(/list\s+# List users with access to clouds defined in Cloudfile/)
      invoke(@cli_user, :help)
    end
  end

  describe "#list" do
    let(:response) {
      [{'email' => 'user@example.com', 'active' => true},
       {'email' => 'auser2@example2.com', 'active' => false}]
    }
    before do
      @cloudfile = Shelly::Cloudfile.new
      Shelly::Cloudfile.stub(:new).and_return(@cloudfile)
    end

    it "should ensure user has logged in" do
      hooks(@cli_user, :list).should include(:logged_in?)
    end

    it "should ensure that Cloudfile is present" do
      hooks(@cli_user, :list).should include(:cloudfile_present?)
    end

    context "on success" do
      it "should receive clouds from the Cloudfile" do
        @client.stub(:collaborations).and_return(response)
        @cloudfile.should_receive(:clouds).and_return(["foo-staging", "foo-production"])
        invoke(@cli_user, :list)
      end

      it "should display clouds and users" do
        @client.stub(:collaborations).and_return(response)
        $stdout.should_receive(:puts).with("Cloud foo-production:")
        $stdout.should_receive(:puts).with("  user@example.com")
        $stdout.should_receive(:puts).with("  auser2@example2.com (invited)")
        invoke(@cli_user, :list)
      end
    end

    context "on failure" do
      it "should exit with 1 if user does not have access to cloud" do
        exception = Shelly::Client::NotFoundException.new("resource" => "cloud")
        @client.stub(:collaborations).and_raise(exception)
        $stdout.should_receive(:puts).with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
        lambda { invoke(@cli_user, :list) }.should raise_error(SystemExit)
      end
    end
  end

  describe "#add" do
    before do
      @user = Shelly::User.new
      @client.stub(:apps).and_return([{"code_name" => "abc"}, {"code_name" => "fooo"}])
      Shelly::User.stub(:new).and_return(@user)
    end

    it "should ensure user has logged in" do
      hooks(@cli_user, :add).should include(:logged_in?)
    end

    it "should ensure that Cloudfile is present" do
      hooks(@cli_user, :add).should include(:cloudfile_present?)
    end

    context "on success" do
      before do
        @client.should_receive(:send_invitation).with("foo-production", "megan@example.com")
        @client.should_receive(:send_invitation).with("foo-staging", "megan@example.com")
      end

      it "should ask about email" do
        fake_stdin(["megan@example.com"]) do
          invoke(@cli_user, :add)
        end
      end

      it "should receive clouds from the Cloudfile" do
        invoke(@cli_user, :add, "megan@example.com")
      end

      it "should receive clouds from the Cloudfile" do
        $stdout.should_receive(:puts).with("\e[32mSending invitation to megan@example.com to work on foo-production\e[0m")
        invoke(@cli_user, :add, "megan@example.com")
      end
    end

    context "on failure" do
      it "should raise error if user doesnt have access to cloud" do
        exception = Shelly::Client::NotFoundException.new("resource" => "cloud")
        @client.stub(:send_invitation).and_raise(exception)
        $stdout.should_receive(:puts).with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
        lambda {
          invoke(@cli_user, :add, "megan@example.com")
        }.should raise_error(SystemExit)
      end
    end
  end

  describe "#delete" do
    before do
      @user = Shelly::User.new
      @client.stub(:apps).and_return([{"code_name" => "abc"}, {"code_name" => "fooo"}])
      Shelly::User.stub(:new).and_return(@user)
    end

    it "should ensure user has logged in" do
      hooks(@cli_user, :delete).should include(:logged_in?)
    end

    it "should ensure that Cloudfile is present" do
      hooks(@cli_user, :delete).should include(:cloudfile_present?)
    end

    context "on success" do
      it "should ask about email" do
        @client.should_receive(:delete_collaboration).with("foo-production", "megan@example.com")
        @client.should_receive(:delete_collaboration).with("foo-staging", "megan@example.com")
        fake_stdin(["megan@example.com"]) do
          invoke(@cli_user, :delete)
        end
      end

      it "should receive email from param" do
        @client.should_receive(:delete_collaboration).with("foo-production", "megan@example.com")
        @client.should_receive(:delete_collaboration).with("foo-staging", "megan@example.com")
        invoke(@cli_user, :delete, "megan@example.com")
      end

      it "should show that user was removed" do
        @client.stub(:delete_collaboration)
        $stdout.should_receive(:puts).with("User megan@example.com deleted from cloud foo-production")
        $stdout.should_receive(:puts).with("User megan@example.com deleted from cloud foo-staging")
        invoke(@cli_user, :delete, "megan@example.com")
      end
    end

    context "on failure" do
      it "should show that user wasn't found" do
        exception = Shelly::Client::NotFoundException.new("resource" => "user")
        @client.stub(:delete_collaboration).and_raise(exception)
        $stdout.should_receive(:puts).with(red "User 'megan@example.com' not found")
        $stdout.should_receive(:puts).with(red "You can list users with `shelly user list`")
        lambda {
          invoke(@cli_user, :delete, "megan@example.com")
        }.should raise_error(SystemExit)
      end

      it "should raise error if user doesnt have access to cloud" do
        exception = Shelly::Client::NotFoundException.new("resource" => "cloud")
        @client.stub(:delete_collaboration).and_raise(exception)
        $stdout.should_receive(:puts).with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
        lambda {
          invoke(@cli_user, :delete, "megan@example.com")
        }.should raise_error(SystemExit)
      end
    end
  end
end
