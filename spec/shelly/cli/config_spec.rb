require "spec_helper"
require "shelly/cli/config"

describe Shelly::CLI::Config do

  before do
    FileUtils.stub(:chmod)
    @config = Shelly::CLI::Config.new
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
        @config.list
      }.should raise_error(SystemExit)
    end

    it "should exit if user doesn't have access to cloud in Cloudfile" do
      response = {"message" => "Cloud foo-staging not found"}
      exception = Shelly::Client::APIError.new(response.to_json)
      @client.stub(:app_configs).and_raise(exception)
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
      lambda { @config.list }.should raise_error(SystemExit)
    end

    it "should list available configuration files for clouds" do
      @client.should_receive(:app_configs).with("foo-staging").and_return([{"id" => 1, "created_by_user" => true, "path" => "config/settings.yml"}])
      @client.should_receive(:app_configs).with("foo-production").and_return([{"id" => 2, "created_by_user" => false, "path" => "config/app.yml"}])
      $stdout.should_receive(:puts).with(green "Configuration files for foo-production")
      $stdout.should_receive(:puts).with("You have no custom configuration files.")
      $stdout.should_receive(:puts).with("Following files are created by Shelly Cloud:")
      $stdout.should_receive(:puts).with(/ * 2\s+config\/app.yml/)
      $stdout.should_receive(:puts).with(green "Configuration files for foo-staging")
      $stdout.should_receive(:puts).with("Custom configuration files:")
      $stdout.should_receive(:puts).with(/ * 1\s+config\/settings.yml/)

      @config.list
    end

  end

  describe "#show" do
    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with(red "No Cloudfile found")
      lambda { @config.show(1) }.should raise_error(SystemExit)
    end

    it "should exit if no id was specified" do
      $stdout.should_receive(:puts).with(red "No configuration file specified")
      lambda { @config.show }.should raise_error(SystemExit)
    end

    it "should show config" do
      @client.should_receive(:app_config).with("foo-staging", 1).and_return({"path" => "test.rb", "content" => "example content"})
      $stdout.should_receive(:puts).with(green "Content of test.rb:")
      $stdout.should_receive(:puts).with("example content")
      @config.show(1)
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show info to select cloud and exit" do
        $stdout.should_receive(:puts).with("You have multiple clouds in Cloudfile. Specify cloud using:")
        lambda { @config.show(1) }.should raise_error(SystemExit)
      end

      it "should use cloud specified by parameter" do
        @client.should_receive(:app_config).with("foo-production", 1).and_return({"path" => "test.rb", "content" => "example content"})
        @config.options = {:cloud => "foo-production"}
        @config.show(1)
      end
    end
  end

  describe "#create" do
    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with(red "No Cloudfile found")
      lambda { @config.create("path") }.should raise_error(SystemExit)
    end

    it "should exit if no id was specified" do
      $stdout.should_receive(:puts).with(red "No path specified")
      lambda { @config.create }.should raise_error(SystemExit)
    end

    it "should ask to set EDITOR environment variable if not set" do
      @config.stub(:system) {false}
      $stdout.should_receive(:puts).with(red "Please set EDITOR environment variable")
      lambda { @config.create("path") }.should raise_error(SystemExit)
    end

    it "should create file" do
      @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
      @client.should_receive(:app_create_config).with("foo-staging", "path", "\n").and_return({})
      $stdout.should_receive(:puts).with(green "File 'path' created, it will be used after next code deploy")
      @config.create("path")
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
        @config.create("path")
      end
    end
  end


  describe "#edit" do
    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with(red "No Cloudfile found")
      lambda { @config.edit(1) }.should raise_error(SystemExit)
    end

    it "should exit if no path was specified" do
      $stdout.should_receive(:puts).with(red "No configuration file specified")
      lambda { @config.edit }.should raise_error(SystemExit)
    end

    it "should ask to set EDITOR environment variable if not set" do
      @client.should_receive(:app_config).with("foo-staging", 1).and_return({"path" => "test.rb", "content" => "example content"})
      @config.stub(:system) {false}
      $stdout.should_receive(:puts).with(red "Please set EDITOR environment variable")
      lambda { @config.edit(1) }.should raise_error(SystemExit)
    end

    it "should create file" do
      @client.should_receive(:app_config).with("foo-staging", 1).and_return({"path" => "test.rb", "content" => "example content"})
      @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
      @client.should_receive(:app_update_config).with("foo-staging", 1, "example content\n").and_return({"path" => "test.rb", "content" => "example content"})
      $stdout.should_receive(:puts).with(green "File 'test.rb' updated, it will be used after next code deploy")
      @config.edit(1)
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show info to select cloud and exit" do
        @config.stub(:system) {true}
        $stdout.should_receive(:puts).with("You have multiple clouds in Cloudfile. Specify cloud using:")
        lambda { @config.edit(1) }.should raise_error(SystemExit)
      end

      it "should use cloud specified by parameter" do
        @client.should_receive(:app_config).with("foo-production", 1).and_return({"path" => "test.rb", "content" => "example content"})
        @config.should_receive(:system).with(/vim \/tmp\/shelly-edit/).and_return(true)
        @client.should_receive(:app_update_config).with("foo-production", 1, "example content\n").and_return({"path" => "test.rb", "content" => "example content"})
        @config.options = {:cloud => "foo-production"}
        @config.edit(1)
      end
    end
  end

  describe "#delete" do
    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with(red "No Cloudfile found")
      lambda { @config.delete(1) }.should raise_error(SystemExit)
    end

    it "should exit if no path was specified" do
      $stdout.should_receive(:puts).with(red "No configuration file specified")
      lambda { @config.delete }.should raise_error(SystemExit)
    end

    it "should delete configuration file" do
      @client.should_receive(:app_config).with("foo-staging", 1).and_return({"path" => "test.rb", "content" => "example content"})
      @client.should_receive(:app_delete_config).with("foo-staging", 1).and_return({})
      $stdout.should_receive(:puts).with(green "File deleted, redeploy your cloud to make changes")
      fake_stdin(["y"]) do
        @config.delete(1)
      end
    end

    it "should not delete file if user answered other than yes/y" do
      @client.should_receive(:app_config).with("foo-staging", 1).and_return({"path" => "test.rb", "content" => "example content"})
      @client.should_not_receive(:app_delete_config)
      $stdout.should_receive(:puts).with("File not deleted")
      fake_stdin(["n"]) do
        @config.delete(1)
      end
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show info to select cloud and exit" do
        $stdout.should_receive(:puts).with("You have multiple clouds in Cloudfile. Specify cloud using:")
        lambda { @config.delete(1) }.should raise_error(SystemExit)
      end

      it "should use cloud specified by parameter" do
        @client.should_receive(:app_config).with("foo-production", 1).and_return({"path" => "test.rb", "content" => "example content"})
        @client.should_receive(:app_delete_config).with("foo-production", 1).and_return({})
        $stdout.should_receive(:puts).with(green "File deleted, redeploy your cloud to make changes")
        @config.options = {:cloud => "foo-production"}
        fake_stdin(["y"]) do
          @config.delete(1)
        end
      end
    end
  end
end