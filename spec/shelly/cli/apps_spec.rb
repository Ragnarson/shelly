require "spec_helper"
require "shelly/cli/apps"

describe Shelly::CLI::Apps do
  before do
    @apps = Shelly::CLI::Apps.new
    $stdout.stub(:print)
  end

  describe "#add" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      @app = Shelly::App.new
      Shelly::App.stub(:new).and_return(@app)
    end

    it "should ask user how he will use application" do
      $stdout.should_receive(:print).with("How will you use this system (production - default,staging): ")
      @app.should_receive(:purpose=).with("staging")
      fake_stdin(["staging", "", ""]) do
        @apps.add
      end
    end

    context "when user provided empty purpose" do
      it "should use 'production' as default" do
        $stdout.should_receive(:print).with("How will you use this system (production - default,staging): ")
        @app.should_receive(:purpose=).with("production")
        fake_stdin(["", "", ""]) do
          @apps.add
        end
      end
    end

    it "should use code name provided by user" do
      $stdout.should_receive(:print).with("How will you use this system (production - default,staging): ")
      $stdout.should_receive(:print).with("Application code name (foo-staging - default): ")
      @app.should_receive(:code_name=).with("mycodename")
      fake_stdin(["staging", "mycodename", ""]) do
        @apps.add
      end
    end

    context "when user provided empty code name" do
      it "should use 'current_dirname-purpose' as default" do
        $stdout.should_receive(:print).with("How will you use this system (production - default,staging): ")
        $stdout.should_receive(:print).with("Application code name (foo-staging - default): ")
        fake_stdin(["staging", "", ""]) do
          @apps.add
        end
      end
    end

    it "should use database provided by user (separated by comma or space)" do
      $stdout.should_receive(:print).with("Which database do you want to use postgresql, mongodb, redis, none (postgresql - default): ")
      @app.should_receive(:databases=).with(["postgresql", "mongo", "redis"])
      fake_stdin(["staging", "", "postgresql,mongo redis"]) do
        @apps.add
      end
    end

    context "when user provided empty database" do
      it "should use 'postgresql' database as default" do
        @app.should_receive(:databases=).with(["postgresql"])
        fake_stdin(["staging", "", ""]) do
          @apps.add
        end
      end
    end

    it "should add git remote"

    it "should create Cloudfile"

    it "should browser window with link to edit billing information"

    it "should display info about adding Cloudfile to repository"
    it "should display info on how to deploy to ShellyCloud"

  end
end