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
    File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
    FileUtils.mkdir_p("/tmp")
    Dir.stub(:tmpdir).and_return("/tmp")
    ENV["EDITOR"] = "vim"
  end

  describe "#list" do
    before do
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
    end

    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with(red "No Cloudfile found")
      lambda {
        invoke(@config, :list)
      }.should raise_error(SystemExit)
    end

    it "should exit if user doesn't have access to cloud in Cloudfile" do
      response = {"message" => "Couldn't find Cloud with code_name = foo-staging"}
      exception = Shelly::Client::APIError.new(404, response)
      @client.stub(:app_configs).and_raise(exception)
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
      lambda { invoke(@config, :list) }.should raise_error(SystemExit)
    end

    it "should list available configuration files for clouds" do
      @client.should_receive(:app_configs).with("foo-staging").and_return([{"created_by_user" => true, "path" => "config/settings.yml"}])
      @client.should_receive(:app_configs).with("foo-production").and_return([{"created_by_user" => false, "path" => "config/app.yml"}])
      $stdout.should_receive(:puts).with(green "Configuration files for foo-production")
      $stdout.should_receive(:puts).with("You have no custom configuration files.")
      $stdout.should_receive(:puts).with("Following files are created by Shelly Cloud:")
      $stdout.should_receive(:puts).with(/ * \s+config\/app.yml/)
      $stdout.should_receive(:puts).with(green "Configuration files for foo-staging")
      $stdout.should_receive(:puts).with("Custom configuration files:")
      $stdout.should_receive(:puts).with(/ * \s+config\/settings.yml/)

      invoke(@config, :list)
    end

  end

  describe "#show" do
    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with(red "No Cloudfile found")
      lambda { invoke(@config, :show) }.should raise_error(SystemExit)
    end

    it "should exit if no path was specified" do
      $stdout.should_receive(:puts).with(red "No configuration file specified")
      lambda { invoke(@config, :show) }.should raise_error(SystemExit)
    end

    it "should show config" do
      @client.should_receive(:app_config).with("foo-staging", "path").and_return({"path" => "test.rb", "content" => "example content"})
      $stdout.should_receive(:puts).with(green "Content of test.rb:")
      $stdout.should_receive(:puts).with("example content")
      invoke(@config, :show, "path")
    end

    describe "on failure" do
      context "when config doesn't exist" do
        it "should display error message and exit with 1" do
          exception = Shelly::Client::APIError.new(404, {"message" => "Couldn't find Config with"})
          @client.should_receive(:app_config).and_raise(exception)
          $stdout.should_receive(:puts).with(red "Config 'config/app.yml' not found")
          $stdout.should_receive(:puts).with(red "You can list available config files with `shelly config list --cloud foo-staging`")
          lambda {
            invoke(@config, :show, "config/app.yml")
          }.should raise_error(SystemExit)
        end
      end

      context "when user doesn't have access to cloud" do
        it "should display error message and exit with 1" do
          exception = Shelly::Client::APIError.new(404, {"message" => "Couldn't find Cloud with"})
          @client.should_receive(:app_config).and_raise(exception)
          $stdout.should_receive(:puts).with(red "You have no access to 'foo-staging' cloud defined in Cloudfile")
          lambda {
            invoke(@config, :show, "config/app.yml")
          }.should raise_error(SystemExit)
        end
      end
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show info to select cloud and exit" do
        $stdout.should_receive(:puts).with("You have multiple clouds in Cloudfile. Specify cloud using:")
        lambda { invoke(@config, :show, "path") }.should raise_error(SystemExit)
      end

      it "should use cloud specified by parameter" do
        @client.should_receive(:app_config).with("foo-production", "path").and_return({"path" => "test.rb", "content" => "example content"})
        @config.options = {:cloud => "foo-production"}
        invoke(@config, :show, "path")
      end
    end
  end

  describe "#create" do
    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with(red "No Cloudfile found")
      lambda { invoke(@config, :create, "path") }.should raise_error(SystemExit)
    end

    it "should exit if no path was specified" do
      $stdout.should_receive(:puts).with(red "No path specified")
      lambda { invoke(@config, :create) }.should raise_error(SystemExit)
    end

    it "should ask to set EDITOR environment variable if not set" do
      @config.stub(:system) {false}
      $stdout.should_receive(:puts).with(red "Please set EDITOR environment variable")
      lambda { invoke(@config, :create, "path") }.should raise_error(SystemExit)
    end

    it "should create file" do
      @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
      @client.should_receive(:app_create_config).with("foo-staging", "path", "\n").and_return({})
      $stdout.should_receive(:puts).with(green "File 'path' created, it will be used after next code deploy")
      invoke(@config, :create, "path")
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show info to select cloud and exit" do
        @config.stub(:system) {true}
        $stdout.should_receive(:puts).with("You have multiple clouds in Cloudfile. Specify cloud using:")
        lambda { @config.create("path") }.should raise_error(SystemExit)
      end

      it "should use cloud specified by parameter" do
        @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
        @client.should_receive(:app_create_config).with("foo-production", "path", "\n").and_return({})
        @config.options = {:cloud => "foo-production"}
        invoke(@config, :create, "path")
      end
    end
  end


  describe "#edit" do
    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with(red "No Cloudfile found")
      lambda { invoke(@config, :edit, "path") }.should raise_error(SystemExit)
    end

    it "should exit if no path was specified" do
      $stdout.should_receive(:puts).with(red "No configuration file specified")
      lambda { invoke(@config, :edit) }.should raise_error(SystemExit)
    end

    it "should ask to set EDITOR environment variable if not set" do
      @client.should_receive(:app_config).with("foo-staging", "path").and_return({"path" => "test.rb", "content" => "example content"})
      @config.stub(:system) {false}
      $stdout.should_receive(:puts).with(red "Please set EDITOR environment variable")
      lambda { invoke(@config, :edit, "path") }.should raise_error(SystemExit)
    end

    it "should create file" do
      @client.should_receive(:app_config).with("foo-staging", "path").and_return({"path" => "test.rb", "content" => "example content"})
      @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
      @client.should_receive(:app_update_config).with("foo-staging", "path", "example content\n").and_return({"path" => "test.rb", "content" => "example content"})
      $stdout.should_receive(:puts).with(green "File 'test.rb' updated, it will be used after next code deploy")
      invoke(@config, :edit, "path")
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show info to select cloud and exit" do
        @config.stub(:system) {true}
        $stdout.should_receive(:puts).with("You have multiple clouds in Cloudfile. Specify cloud using:")
        lambda { invoke(@config, :edit, "path") }.should raise_error(SystemExit)
      end

      it "should use cloud specified by parameter" do
        @client.should_receive(:app_config).with("foo-production", "path").and_return({"path" => "test.rb", "content" => "example content"})
        @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
        @client.should_receive(:app_update_config).with("foo-production", "path", "example content\n").and_return({"path" => "test.rb", "content" => "example content"})
        @config.options = {:cloud => "foo-production"}
        invoke(@config, :edit, "path")
      end
    end
  end

  describe "#delete" do
    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with(red "No Cloudfile found")
      lambda { invoke(@config, :delete) }.should raise_error(SystemExit)
    end

    it "should exit if no path was specified" do
      $stdout.should_receive(:puts).with(red "No configuration file specified")
      lambda { invoke(@config, :delete) }.should raise_error(SystemExit)
    end

    it "should delete configuration file" do
      @client.should_receive(:app_delete_config).with("foo-staging", "path").and_return({})
      $stdout.should_receive(:puts).with(green "File deleted, redeploy your cloud to make changes")
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

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show info to select cloud and exit" do
        $stdout.should_receive(:puts).with("You have multiple clouds in Cloudfile. Specify cloud using:")
        lambda { invoke(@config, :delete, "path") }.should raise_error(SystemExit)
      end

      it "should use cloud specified by parameter" do
        @client.should_receive(:app_delete_config).with("foo-production", "path").and_return({})
        $stdout.should_receive(:puts).with(green "File deleted, redeploy your cloud to make changes")
        @config.options = {:cloud => "foo-production"}
        fake_stdin(["y"]) do
          invoke(@config, :delete, "path")
        end
      end
    end
  end
end