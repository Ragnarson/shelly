require "spec_helper"
require "shelly/cli/deploy"

describe Shelly::CLI::Deploy do
  before do
    FileUtils.stub(:chmod)
    @deploys = Shelly::CLI::Deploy.new
    Shelly::CLI::Deploy.stub(:new).and_return(@deploys)
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    $stdout.stub(:puts)
    $stdout.stub(:print)
    @app = Shelly::App.new("foo-staging")
  end

  describe "#list" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
      @client.stub(:authorize!)
    end

    it "should ensure user has logged in" do
      hooks(@deploys, :list).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.should_receive(:deploy_logs).with("foo-staging").and_return([
        {"failed" => false, "created_at" => "2011-12-12-14-14-59"}])
      @deploys.should_receive(:multiple_clouds).and_return(@app)
      invoke(@deploys, :list)
    end

    it "should display available logs" do
      @client.should_receive(:deploy_logs).with("foo-staging").and_return([
        {"failed" => false, "created_at" => "2011-12-12-14-14-59", "author" => "wijet", "commit_sha" => "69fb7a9b5101969f284db15b937ea23e579b3d4d"},
          {"failed" => true, "created_at" => "2011-12-12-15-14-59", "author" => "sabcio", "commit_sha" => "ac37e1993fea54ddbadaf7654b7ab0fa381d202b"},
          {"failed" => false, "created_at" => "2011-12-12-16-14-59", "author" => nil, "commit_sha" => nil},
          {"failed" => true, "created_at" => "2011-12-12-17-14-59", "author" => nil, "commit_sha" => nil},
          {"failed" => false, "created_at" => "2011-12-12-18-14-59", "author" => "wijet", "commit_sha" => nil}])
      $stdout.should_receive(:puts).with(green "Available deploy logs")
      $stdout.should_receive(:puts).with(" * 2011-12-12-14-14-59 69fb7a9 by wijet")
      $stdout.should_receive(:puts).with(" * 2011-12-12-15-14-59 ac37e19 by sabcio (failed)")
      $stdout.should_receive(:puts).with(" * 2011-12-12-16-14-59")
      $stdout.should_receive(:puts).with(" * 2011-12-12-17-14-59 (failed)")
      $stdout.should_receive(:puts).with(" * 2011-12-12-18-14-59 redeploy by wijet")
      invoke(@deploys, :list)
    end
  end

  describe "#show" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
      @client.stub(:authorize!)
    end

    it "should ensure user has logged in" do
      hooks(@deploys, :show).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.should_receive(:deploy_log).with("foo-staging", "last").and_return(response)
      @deploys.should_receive(:multiple_clouds).and_return(@app)
      invoke(@deploys, :show, "last")
    end

    context "log not found" do
      it "should exit 1 with message" do
        exception = Shelly::Client::NotFoundException.new("resource" => "log")
        @client.stub(:deploy_log).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Log not found, list all deploy logs using `shelly deploys list --cloud=foo-staging`")
        lambda { @deploys.show("last") }.should raise_error(SystemExit)
      end
    end

    context "single cloud" do
      it "should render logs without passing cloud" do
        @client.should_receive(:deploy_log).with("foo-staging", "last").and_return(response)
        expected_output
        invoke(@deploys, :show, "last")
      end
    end

    context "log is missing" do
      it "should show error about contact support" do
        @client.should_receive(:deploy_log).with("foo-staging", "last").and_return({})
        $stdout.should_receive(:puts).with(red "There was an error and log is not available")
        $stdout.should_receive(:puts).with(red "Please contact our support https://shellycloud.com/support")
        lambda { invoke(@deploys, :show, "last") }.should raise_error(SystemExit)
      end
    end

    def expected_output
      $stdout.should_receive(:puts).with(green "Log for deploy done on 2011-12-12 at 14:14:59")
      $stdout.should_receive(:puts).with(green "Starting bundle install")
      $stdout.should_receive(:puts).with("Installing gems")
      $stdout.should_receive(:puts).with(green "Starting whenever")
      $stdout.should_receive(:puts).with("Looking up schedule.rb")
      $stdout.should_receive(:puts).with(green "Starting callbacks")
      $stdout.should_receive(:puts).with("rake db:migrate")
      $stdout.should_receive(:puts).with(green "Starting delayed job")
      $stdout.should_receive(:puts).with("delayed jobs")
      $stdout.should_receive(:puts).with(green "Starting sidekiq")
      $stdout.should_receive(:puts).with("sidekiq workers")
      $stdout.should_receive(:puts).with(green "Starting thin")
      $stdout.should_receive(:puts).with("thins up and running")
      $stdout.should_receive(:puts).with(green "Starting puma")
      $stdout.should_receive(:puts).with("pumas up and running")
    end

    def response
      {"created_at" => "2011-12-12 at 14:14:59", "bundle_install" => "Installing gems",
        "whenever" => "Looking up schedule.rb", "thin_restart" => "thins up and running",
        "puma_restart" => "pumas up and running", "delayed_job" => "delayed jobs",
        "sidekiq" => "sidekiq workers", "callbacks" => "rake db:migrate"}
    end
  end

  describe "#pending" do
    before do
      @app.stub(:deployed? => true)
      @deploys.stub(:multiple_clouds => @app)
    end

    it "should ensure that user is inside git repo" do
      hooks(@deploys, :pending).should include(:inside_git_repository?)
    end

    it "should fetch git references from shelly" do
      $stdout.should_receive(:puts).with("Running: git fetch shelly")
      @app.should_receive(:git_fetch_remote)
      @app.stub(:pending_commits => "commit")
      invoke(@deploys, :pending)
    end

    context "when application has been deployed" do
      context "and has pending commits to deploy" do
        it "should display them" do
          text = "643124c Something (2 days ago)\nd1b8bec Something new (10 days ago)"
          $stdout.should_receive(:puts).with(text)
          @app.stub(:pending_commits => text)
          invoke(@deploys, :pending)
        end
      end

      context "and doesn't have pending commits to deploy" do
        it "should display a message that everything is deployed" do
          $stdout.should_receive(:puts).with(green "All changes are deployed to Shelly Cloud")
          @app.stub(:pending_commits => "")
          invoke(@deploys, :pending)
        end
      end
    end

    context "when application hasn't been deployed" do
      it "should display error" do
        @app.stub(:deployed? => false)
        $stdout.should_receive(:puts).with(red "No commits to show. Application hasn't been deployed yet")
        lambda { invoke(@deploys, :pending) }.should raise_error(SystemExit)
      end
    end
  end
end
