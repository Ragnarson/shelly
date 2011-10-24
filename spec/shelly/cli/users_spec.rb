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

  describe "#list" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      @app = mock
      Shelly::App.stub(:new).and_return(@app)
      Shelly::App.stub(:inside_git_repository?).and_return(true)
    end

    it "should exit with message if command run outside git repository" do
      Shelly::App.stub(:inside_git_repository?).and_return(false)
      $stdout.should_receive(:puts).with("Must be run inside your project git repository")
      lambda {
        @users.list
      }.should raise_error(SystemExit)
    end

    context "on success" do
      it "should receive clouds from the Cloudfile" do
        @app.should_receive(:users).with(["foo-production","foo-staging"]).
          and_return(json_response)
        @users.list
      end

      it "should display clouds and users" do
        @app.stub(:users).and_return(json_response)
        $stdout.should_receive(:puts).with("Cloud foo-staging:")
        $stdout.should_receive(:puts).with("  user@example.com (username)")
        $stdout.should_receive(:puts).with("Cloud foo-production:")
        $stdout.should_receive(:puts).with("  user2@example.com (username2)")
        @users.list
      end

      def json_response
        ["{\"code_name\":\"foo-staging\",\"users\":[{\"name\":\"username\",\"email\":\"user@example.com\"}]}",
         "{\"code_name\":\"foo-production\",\"users\":[{\"name\":\"username2\",\"email\":\"user2@example.com\"}]}"]
      end
    end

    context "on failure" do
      it "should raise an error if user does not have to any app" do
        response = {"message" => "You do not have access to this app"}
        exception = Shelly::Client::APIError.new(response.to_json)
        @app.stub(:users).and_raise(exception)
        $stdout.should_receive(:puts).with("You do not have access to this app")
        lambda { @users.list }.should raise_error(SystemExit)
      end
    end
  end
end

