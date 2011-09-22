require "spec_helper"
require "shelly/cli/apps"

describe Shelly::CLI::Apps do
  before do
    @apps = Shelly::CLI::Apps.new
    $stdout.stub(:print)
    $stdout.stub(:puts)
  end

  describe "#add" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      @app = Shelly::App.new
      @app.stub(:add_git_remote)
      @app.stub(:generate_cloudfile).and_return("Example Cloudfile")
      @app.stub(:open_billing_page)
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
      @app.should_receive(:databases=).with(["postgresql", "mongodb", "redis"])
      fake_stdin(["staging", "", "postgresql,mongodb redis"]) do
        @apps.add
      end
    end

    it "should validate databases" do
      $stdout.should_receive(:print).with("Which database do you want to use postgresql, mongodb, redis, none (postgresql - default): ")
      $stdout.should_receive(:print).with("Unknown database kind. Supported are: postgresql, mongodb, redis, none: ")
      fake_stdin(["staging", "", "postgresql,doesnt-exist", "none"]) do
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

    it "should add git remote" do
      @app.should_receive(:add_git_remote)
      fake_stdin(["staging", "foooo", ""]) do
        @apps.add
      end
    end

    it "should create Cloudfile" do
      File.exists?("/projects/foo/Cloudfile").should be_false
      fake_stdin(["staging", "foooo", ""]) do
        @apps.add
      end
      File.read("/projects/foo/Cloudfile").should == "Example Cloudfile"
    end

    it "should browser window with link to edit billing information" do
      $stdout.should_receive(:puts).with("Provide billing details. Opening browser...")
      @app.should_receive(:open_billing_page)
      fake_stdin(["staging", "foooo", ""]) do
        @apps.add
      end
    end

    it "should display info about adding Cloudfile to repository" do
      $stdout.should_receive(:puts).with("Project is now configured for use with Shell Cloud:")
      $stdout.should_receive(:puts).with("You can review changes using")
      $stdout.should_receive(:puts).with("  git diff")
      fake_stdin(["staging", "foooo", "none"]) do
        @apps.add
      end
    end

    it "should display info on how to deploy to ShellyCloud" do
      $stdout.should_receive(:puts).with("When you make sure all settings are correct please issue following commands:")
      $stdout.should_receive(:puts).with("  git add .")
      $stdout.should_receive(:puts).with('  git commit -m "Application added to Shelly Cloud"')
      $stdout.should_receive(:puts).with("  git push")
      $stdout.should_receive(:puts).with("Deploy to staging using:")
      $stdout.should_receive(:puts).with("  git push staging master")
      fake_stdin(["staging", "foooo", "none"]) do
        @apps.add
      end
    end
  end
end

