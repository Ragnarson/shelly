require "spec_helper"
require "shelly/cli/config"

describe Shelly::CLI::Config do

  before do
    FileUtils.stub(:chmod)
    @config = Shelly::CLI::Config.new
    Shelly::CLI::Config.stub(:new).and_return(@config)
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    $stdout.stub(:puts)
    $stdout.stub(:print)
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @client.stub(:token).and_return("abc")
    File.open("Cloudfile", 'w') {|f| f.write("foo-production:\n") }
    FileUtils.mkdir_p("/tmp")
    Dir.stub(:tmpdir).and_return("/tmp")
    ENV["EDITOR"] = "vim"
    @app = Shelly::App.new("foo-production")
  end

  describe "#list" do
    it "should ensure user has logged in" do
      hooks(@config, :list).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.should_receive(:app_configs).with("foo-production").and_return([{"created_by_user" => false, "path" => "config/app.yml"}])
      @config.should_receive(:multiple_clouds).and_return(@app)
      invoke(@config, :list)
    end

    it "should list available configuration files for clouds" do
      @client.should_receive(:app_configs).with("foo-production").and_return([{"created_by_user" => false, "path" => "config/app.yml"}])
      $stdout.should_receive(:puts).with(green "Configuration files for foo-production")
      $stdout.should_receive(:puts).with("You have no custom configuration files.")
      $stdout.should_receive(:puts).with("Following files are created by Shelly Cloud:")
      $stdout.should_receive(:puts).with(/ * \s+config\/app.yml/)

      invoke(@config, :list)
    end
  end

  describe "#show" do
    it "should ensure user has logged in" do
      hooks(@config, :show).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.should_receive(:app_config).with("foo-production", "path").and_return({"path" => "test.rb", "content" => "example content"})
      @config.should_receive(:multiple_clouds).and_return(@app)
      invoke(@config, :show, "path")
    end

    it "should show config" do
      @client.should_receive(:app_config).with("foo-production", "path").and_return({"path" => "test.rb", "content" => "example content"})
      $stdout.should_receive(:puts).with(green "Content of test.rb:")
      $stdout.should_receive(:puts).with("example content")
      invoke(@config, :show, "path")
    end

    describe "on failure" do
      context "when config doesn't exist" do
        it "should display error message and exit with 1" do
          exception = Shelly::Client::NotFoundException.new("resource" => "config")
          @client.should_receive(:app_config).and_raise(exception)
          $stdout.should_receive(:puts).with(red "Config 'config/app.yml' not found")
          $stdout.should_receive(:puts).with(red "You can list available config files with `shelly config list --cloud foo-production`")
          lambda {
            invoke(@config, :show, "config/app.yml")
          }.should raise_error(SystemExit)
        end
      end
    end
  end

  describe "#create" do
    it "should ensure user has logged in" do
      hooks(@config, :create).should include(:logged_in?)
    end

    it "should ensure user has logged in" do
      hooks(@config, :new).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
      @app = Shelly::App.new("foo-production")
      Shelly::App.stub(:new).and_return(@app)
      @client.should_receive(:app_create_config).with("foo-production", "path", "\n").and_return({})
      @config.should_receive(:multiple_clouds).and_return(@app)
      invoke(@config, :create, "path")
    end

    it "should ask to set EDITOR environment variable if not set" do
      @config.stub(:system) {false}
      $stdout.should_receive(:puts).with(red "Please set EDITOR environment variable")
      lambda { invoke(@config, :create, "path") }.should raise_error(SystemExit)
    end

    it "should create file" do
      @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
      @client.should_receive(:app_create_config).with("foo-production", "path", "\n").and_return({})
      $stdout.should_receive(:puts).with(green "File 'path' created.")
      $stdout.should_receive(:puts).with("To make changes to running application redeploy it using:")
      $stdout.should_receive(:puts).with("`shelly redeploy --cloud foo-production`")
      invoke(@config, :create, "path")
    end

    context "on validation errors" do
      it "should display validation errors" do
        exception = Shelly::Client::ValidationException.new({"errors" => [["path", "is already taken"]]})
        @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
        @client.stub(:app_create_config).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Path is already taken")
        lambda {
          invoke(@config, :create, "config/app.yml")
        }.should raise_error(SystemExit)
      end
    end
  end


  describe "#edit" do
    it "should ensure user has logged in" do
      hooks(@config, :edit).should include(:logged_in?)
    end

    it "should ensure user has logged in" do
      hooks(@config, :update).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
      @client.should_receive(:app_config).with("foo-production", "path").and_return({"path" => "test.rb", "content" => "example content"})
      @client.should_receive(:app_update_config).with("foo-production", "path", "example content\n").and_return({"path" => "test.rb", "content" => "example content"})
      @config.should_receive(:multiple_clouds).and_return(@app)
      invoke(@config, :edit, "path")
    end

    it "should ask to set EDITOR environment variable if not set" do
      @client.should_receive(:app_config).with("foo-production", "path").and_return({"path" => "test.rb", "content" => "example content"})
      @config.stub(:system) {false}
      $stdout.should_receive(:puts).with(red "Please set EDITOR environment variable")
      lambda { invoke(@config, :edit, "path") }.should raise_error(SystemExit)
    end

    it "should create file" do
      @client.should_receive(:app_config).with("foo-production", "path").and_return({"path" => "test.rb", "content" => "example content"})
      @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
      @client.should_receive(:app_update_config).with("foo-production", "path", "example content\n").and_return({"path" => "test.rb", "content" => "example content"})
      $stdout.should_receive(:puts).with(green "File 'test.rb' updated.")
      $stdout.should_receive(:puts).with("To make changes to running application redeploy it using:")
      $stdout.should_receive(:puts).with("`shelly redeploy --cloud foo-production`")
      invoke(@config, :edit, "path")
    end

    describe "on failure" do
      context "when config doesn't exist" do
        it "should display error message and exit with 1" do
          exception = Shelly::Client::NotFoundException.new("resource" => "config")
          @client.should_receive(:app_config).and_raise(exception)
          $stdout.should_receive(:puts).with(red "Config 'config/app.yml' not found")
          $stdout.should_receive(:puts).with(red "You can list available config files with `shelly config list --cloud foo-production`")
          lambda {
            invoke(@config, :edit, "config/app.yml")
          }.should raise_error(SystemExit)
        end
      end

      context "on validation errors" do
        it "should display validation errors" do
          exception = Shelly::Client::ValidationException.new({"errors" => [["path", "is already taken"]]})
          @client.should_receive(:app_config).and_raise(exception)
          $stdout.should_receive(:puts).with(red "Path is already taken")
          lambda {
            invoke(@config, :edit, "config/app.yml")
          }.should raise_error(SystemExit)
        end
      end
    end
  end

  describe "#delete" do
    it "should ensure user has logged in" do
      hooks(@config, :delete).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.should_receive(:app_delete_config).with("foo-production", "path").and_return({})
      @config.should_receive(:multiple_clouds).and_return(@app)
      fake_stdin(["y"]) do
        invoke(@config, :delete, "path")
      end
    end

    it "should delete configuration file" do
      @client.should_receive(:app_delete_config).with("foo-production", "path").and_return({})
      $stdout.should_receive(:puts).with(green "File 'path' deleted.")
      $stdout.should_receive(:puts).with("To make changes to running application redeploy it using:")
      $stdout.should_receive(:puts).with("`shelly redeploy --cloud foo-production`")
      fake_stdin(["y"]) do
        invoke(@config, :delete, "path")
      end
    end

    it "should not delete file if user answered other than yes/y" do
      @client.should_not_receive(:app_delete_config)
      $stdout.should_receive(:puts).with("File not deleted")
      fake_stdin(["n"]) do
        invoke(@config, :delete, "path")
      end
    end

    describe "on failure" do
      context "when config doesn't exist" do
        it "should display error message and exit with 1" do
          exception = Shelly::Client::NotFoundException.new("resource" => "config")
          @client.should_receive(:app_delete_config).and_raise(exception)
          $stdout.should_receive(:puts).with(red "Config 'config/app.yml' not found")
          $stdout.should_receive(:puts).with(red "You can list available config files with `shelly config list --cloud foo-production`")
          fake_stdin(["y"]) do
            lambda {
              invoke(@config, :delete, "config/app.yml")
            }.should raise_error(SystemExit)
          end
        end
      end
    end
  end
end
