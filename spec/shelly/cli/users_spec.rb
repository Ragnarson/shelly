require "spec_helper"
require "shelly/cli/users"

describe Shelly::CLI::Users do
  before do
    FileUtils.stub(:chmod)
    @users = Shelly::CLI::Users.new
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    Shelly::User.stub(:guess_email).and_return("")
    $stdout.stub(:puts)
    $stdout.stub(:print)
  end

  describe "#help" do
    it "should show help" do
      expected = <<-OUT
Tasks:
  shelly add EMAIL       # Add new developer to applications defined in Cloudfile
  shelly help [COMMAND]  # Describe subcommands or one specific subcommand
  shelly list            # List users who have access to current application
OUT
      out = IO.popen("bin/shelly users").read.strip
      out.should == expected.strip
    end
  end

  describe "#list" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      Shelly::App.stub(:inside_git_repository?).and_return(true)
    end

    it "should exit with message if command run outside git repository" do
      @client.stub(:app_users).and_return(response)
      Shelly::App.stub(:inside_git_repository?).and_return(false)
      $stdout.should_receive(:puts).with("\e[31mMust be run inside your project git repository\e[0m")
      lambda {
        @users.list
      }.should raise_error(SystemExit)
    end

    context "on success" do
      it "should receive clouds from the Cloudfile" do
        @client.should_receive(:app_users).with(["foo-production", "foo-staging"]).
          and_return(response)
        @users.list
      end

      it "should display clouds and users" do
        @client.stub(:app_users).and_return(response)
        $stdout.should_receive(:puts).with("Cloud foo-staging:")
        $stdout.should_receive(:puts).with("  user@example.com (username)")
        $stdout.should_receive(:puts).with("Cloud foo-production:")
        $stdout.should_receive(:puts).with("  user2@example.com (username2)")
        @users.list
      end
    end

    def response
      [{'code_name' => 'foo-staging','users' => [{'name' => 'username','email' => 'user@example.com'}]},
       {'code_name' => 'foo-production','users' => [{'name' => 'username2','email' => 'user2@example.com'}]}]
    end

    context "on failure" do
      it "should raise an error if user does not have access to any app" do
        response = {"message" => "You do not have access to this app"}
        exception = Shelly::Client::APIError.new(response.to_json)
        @client.stub(:app_users).and_raise(exception)
        $stdout.should_receive(:puts).with("You do not have access to this app")
        lambda { @users.list }.should raise_error(SystemExit)
      end
    end
  end

  describe "#add" do
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

    it "should exit with message if command run outside git repository" do
      Shelly::App.stub(:inside_git_repository?).and_return(false)
      $stdout.should_receive(:puts).with("\e[31mMust be run inside your project git repository\e[0m")
      lambda {
        @users.add
      }.should raise_error(SystemExit)
    end

    context "on success" do
      before do
        @client.should_receive(:send_invitation).with(["foo-production", "foo-staging"], "megan@example.com")
      end

      it "should ask about email" do
        fake_stdin(["megan@example.com"]) do
          @users.add
        end
      end

      it "should receive clouds from the Cloudfile" do
        @users.add("megan@example.com")
      end

      it "should receive clouds from the Cloudfile" do
        $stdout.should_receive(:puts).with("Sending invitation to megan@example.com")
        @users.add("megan@example.com")
      end
    end

  end

end

