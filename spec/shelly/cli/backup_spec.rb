require "spec_helper"
require "shelly/cli/backup"
require "shelly/download_progress_bar"

describe Shelly::CLI::Backup do
  before do
    @backup = Shelly::CLI::Backup.new
    @client = mock
    @client.stub(:token).and_return("abc")
    Shelly::Client.stub(:new).and_return(@client)
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
  end

  describe "#list" do
    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with("\e[31mNo Cloudfile found\e[0m")
      lambda {
        @backup.list
      }.should raise_error(SystemExit)
    end

    it "should exit if user doesn't have access to cloud in Cloudfile" do
      response = {"message" => "Cloud foo-staging not found"}
      exception = Shelly::Client::APIError.new(response.to_json, 401)
      @client.stub(:database_backups).and_raise(exception)
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-staging' cloud defined in Cloudfile")
      lambda { @backup.list }.should raise_error(SystemExit)
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show information to select specific cloud and exit" do
        $stdout.should_receive(:puts).with("You have multiple clouds in Cloudfile. Select cloud to view database backups using:")
        $stdout.should_receive(:puts).with("  shelly backup list foo-production")
        $stdout.should_receive(:puts).with("Available clouds:")
        $stdout.should_receive(:puts).with(" * foo-production")
        $stdout.should_receive(:puts).with(" * foo-staging")
        lambda { @backup.list }.should raise_error(SystemExit)
      end

      it "should take cloud from command line for which to show backups" do
        @client.should_receive(:database_backups).with("foo-staging").and_return([{"filename" => "backup.postgre.tar.gz", "human_size" => "10kb", "size" => 12345},{"filename" => "backup.mongo.tar.gz", "human_size" => "22kb", "size" => 333}])
        $stdout.should_receive(:puts).with(green "Available backups:")
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:puts).with("  Filename               |  Size")
        $stdout.should_receive(:puts).with("  backup.postgre.tar.gz  |  10kb")
        $stdout.should_receive(:puts).with("  backup.mongo.tar.gz    |  22kb")
        @backup.list("foo-staging")
      end
    end
    
    describe "#get" do
      before do
        @client.stub(:download_backup)
        @bar = mock(:progress_callback => @callback)
        Shelly::DownloadProgressBar.stub(:new).and_return(@bar)
        @client.stub(:database_backup).and_return({"filename" => "better.tar.gz", "size" => 12345})
        $stdout.stub(:puts)
      end
      
      it "should make sure that cloud is choosen" do
        @client.should_receive(:database_backup).with("foo-staging", "last")
        @backup.get
              
        @backup.options = {:cloud => "other"}
        @client.should_receive(:database_backup).with("other", "last")
        @backup.get
      end
      
      it "should fetch backup size and initialize download progress bar" do
        @client.stub(:database_backup).and_return({"filename" => "backup.postgres.tar.gz", "size" => 333})
        Shelly::DownloadProgressBar.should_receive(:new).with(333).and_return(@bar)
        
        @backup.get
      end
      
      it "should fetch given backup file itself" do
        @client.should_receive(:download_backup).with("foo-staging", "better.tar.gz", @bar.progress_callback)
        @backup.get("better.tar.gz")
      end
      
      it "should show info where file has been saved" do
        $stdout.should_receive(:puts)
        $stdout.should_receive(:puts).with(green "Backup file saved to better.tar.gz")
        @client.should_receive(:download_backup).with("foo-staging", "better.tar.gz", @bar.progress_callback)
        @backup.get("last")
      end
      
      context "on backup not found" do
        it "it should display error message" do
          exception = Shelly::Client::APIError.new({}.to_json, 404)
          @client.stub(:database_backup).and_raise(exception)
          $stdout.should_receive(:puts).with(red "Backup not found")
          $stdout.should_receive(:puts).with("You can list available backups with 'shelly backup list' command")
          @backup.get("better.tar.gz")
        end
      end
      
      context "on unsupported exception" do
        it "should re-raise it" do
          exception = Shelly::Client::APIError.new({}.to_json, 500)
          @client.stub(:database_backup).and_raise(exception)
          $stdout.should_not_receive(:puts).with(red "Backup not found")
          $stdout.should_not_receive(:puts).with("You can list available backups with 'shelly backup list' command")
          lambda { 
            @backup.get("better.tar.gz") 
          }.should raise_error(Shelly::Client::APIError)
        end
      end
    end
  end
end