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
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      Shelly::App.stub(:inside_git_repository?).and_return(true)
      @cloudfile = Shelly::Cloudfile.new
      Shelly::Cloudfile.stub(:new).and_return(@cloudfile)
    end

    it "should exit with message if command run outside git repository" do
      Shelly::App.stub(:inside_git_repository?).and_return(false)
      $stdout.should_receive(:puts).with("\e[31mMust be run inside your project git repository\e[0m")
      lambda {
        invoke(@cli_user, :list)
      }.should raise_error(SystemExit)
    end

    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with("\e[31mNo Cloudfile found\e[0m")
      lambda {
        invoke(@cli_user, :list)
      }.should raise_error(SystemExit)
    end

    context "on success" do
      it "should receive clouds from the Cloudfile" do
        @client.stub(:app_users).and_return(response)
        @cloudfile.should_receive(:clouds).and_return(["foo-staging", "foo-production"])
        invoke(@cli_user, :list)
      end

      it "should display clouds and users" do
        @client.stub(:app_users).and_return(response)
        $stdout.should_receive(:puts).with("Cloud foo-production:")
        $stdout.should_receive(:puts).with("  user@example.com")
        invoke(@cli_user, :list)
      end
    end

    def response
      [{'email' => 'user@example.com'}]
    end

    context "on failure" do
      it "should exit with 1 if user does not have access to cloud" do
        response = {"message" => "Couldn't find Cloud with code_name = foo-production"}
        exception = Shelly::Client::NotFoundException.new(response)
        @client.stub(:app_users).and_raise(exception)
        $stdout.should_receive(:puts).with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
        lambda { invoke(@cli_user, :list) }.should raise_error(SystemExit)
      end
    end
  end

  describe "#add" do
    # FIXME: it can have common before with #list
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      Shelly::App.stub(:inside_git_repository?).and_return(true)
      @client.stub(:token).and_return("abc")
      @user = Shelly::User.new
      @client.stub(:apps).and_return([{"code_name" => "abc"}, {"code_name" => "fooo"}])
      Shelly::User.stub(:new).and_return(@user)
    end

    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with("\e[31mNo Cloudfile found\e[0m")
      lambda {
        invoke(@cli_user, :add)
      }.should raise_error(SystemExit)
    end

    it "should exit with message if command run outside git repository" do
      Shelly::App.stub(:inside_git_repository?).and_return(false)
      $stdout.should_receive(:puts).with("\e[31mMust be run inside your project git repository\e[0m")
      lambda {
        invoke(@cli_user, :add)
      }.should raise_error(SystemExit)
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
        response = {"message" => "Couldn't find Cloud with"}
        exception = Shelly::Client::NotFoundException.new(response)
        @client.stub(:send_invitation).and_raise(exception)
        $stdout.should_receive(:puts).with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
        lambda {
          invoke(@cli_user, :add, "megan@example.com")
        }.should raise_error(SystemExit)
      end
    end
  end
end
