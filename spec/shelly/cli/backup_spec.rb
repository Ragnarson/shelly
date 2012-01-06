require "spec_helper"
require "shelly/cli/backup"
require "shelly/download_progress_bar"

describe Shelly::CLI::Backup do
  before do
    @backup = Shelly::CLI::Backup.new
    Shelly::CLI::Backup.stub(:new).and_return(@backup)
    @client = mock
    @client.stub(:token).and_return("abc")
    Shelly::Client.stub(:new).and_return(@client)
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
  end

  describe "#list" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') { |f| f.write("foo-staging:\n") }
    end

    it "should ensure user has logged in" do
      hooks(@backup, :list).should include(:logged_in?)
    end

    it "should ensure that Cloudfile is present" do
      hooks(@backup, :list).should include(:cloudfile_present?)
    end

    it "should exit if user doesn't have access to cloud in Cloudfile" do
      exception = Shelly::Client::NotFoundException.new("resource" => "cloud")
      @client.stub(:database_backups).and_raise(exception)
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-staging' cloud defined in Cloudfile")
      lambda { invoke(@backup, :list) }.should raise_error(SystemExit)
    end

    context "multiple clouds" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show information to select specific cloud and exit" do
        $stdout.should_receive(:puts).with("You have multiple clouds in Cloudfile. Select cloud to view database backups for using:")
        $stdout.should_receive(:puts).with("  shelly backup list --cloud foo-production")
        $stdout.should_receive(:puts).with("Available clouds:")
        $stdout.should_receive(:puts).with(" * foo-production")
        $stdout.should_receive(:puts).with(" * foo-staging")
        lambda { invoke(@backup, :list) }.should raise_error(SystemExit)
      end

      it "should take cloud from command line for which to show backups" do
        @client.should_receive(:database_backups).with("foo-staging").and_return([{"filename" => "backup.postgre.tar.gz", "human_size" => "10kb", "size" => 12345},{"filename" => "backup.mongo.tar.gz", "human_size" => "22kb", "size" => 333}])
        $stdout.should_receive(:puts).with(green "Available backups:")
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:puts).with("  Filename               |  Size")
        $stdout.should_receive(:puts).with("  backup.postgre.tar.gz  |  10kb")
        $stdout.should_receive(:puts).with("  backup.mongo.tar.gz    |  22kb")
        @backup.options = {:cloud => "foo-staging"}
        invoke(@backup, :list)
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

      it "should ensure user has logged in" do
        hooks(@backup, :get).should include(:logged_in?)
      end

      it "should make sure that cloud is choosen" do
        @client.should_receive(:database_backup).with("foo-staging", "last")
        invoke(@backup, :get)
      end

      it "should make sure that cloud is choosen" do
        @client.should_receive(:database_backup).with("other", "last")
        @backup.options = {:cloud => "other"}
        invoke(@backup, :get)
      end

      it "should fetch backup size and initialize download progress bar" do
        @client.stub(:database_backup).and_return({"filename" => "backup.postgres.tar.gz", "size" => 333})
        Shelly::DownloadProgressBar.should_receive(:new).with(333).and_return(@bar)

        invoke(@backup, :get)
      end

      it "should fetch given backup file itself" do
        @client.should_receive(:download_backup).with("foo-staging", "better.tar.gz", @bar.progress_callback)
        invoke(@backup, :get, "better.tar.gz")
      end

      it "should show info where file has been saved" do
        $stdout.should_receive(:puts)
        $stdout.should_receive(:puts).with(green "Backup file saved to better.tar.gz")
        @client.should_receive(:download_backup).with("foo-staging", "better.tar.gz", @bar.progress_callback)
        invoke(@backup, :get, "last")
      end

      context "on backup not found" do
        it "it should display error message" do
          exception = Shelly::Client::NotFoundException.new({"resource" => "database_backup"})
          @client.stub(:database_backup).and_raise(exception)
          $stdout.should_receive(:puts).with(red "Backup not found")
          $stdout.should_receive(:puts).with("You can list available backups with `shelly backup list` command")
          invoke(@backup, :get, "better.tar.gz")
        end
      end

      context "on unsupported exception" do
        it "should re-raise it" do
          exception = Shelly::Client::APIException.new
          @client.stub(:database_backup).and_raise(exception)
          $stdout.should_not_receive(:puts).with(red "Backup not found")
          $stdout.should_not_receive(:puts).with("You can list available backups with `shelly backup list` command")
          lambda {
            invoke(@backup, :get, "better.tar.gz")
          }.should raise_error(Shelly::Client::APIException)
        end
      end
    end
  end

  describe "create" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
    end

    it "should ensure user has logged in" do
      hooks(@backup, :create).should include(:logged_in?)
    end

    it "should exit if user doesn't have access to cloud in Cloudfile" do
      exception = Shelly::Client::NotFoundException.new({"resource" => "cloud"})
      @client.stub(:request_backup).and_raise(exception)
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-staging' cloud defined in Cloudfile")
      lambda { invoke(@backup, :create) }.should raise_error(SystemExit)
    end

    it "should display errors and exit 1 when kind is not valid" do
      response = {"message" => "Wrong KIND argument. User one of following: postgresql, mongodb, redis"}
      exception = Shelly::Client::ValidationException.new(response)
      @client.should_receive(:request_backup).and_raise(exception)
      $stdout.should_receive(:puts).with(red response["message"])
      lambda { invoke(@backup, :create) }.should raise_error(SystemExit)
    end

    it "should display information about request backup" do
      @client.stub(:request_backup)
      $stdout.should_receive(:puts).with(green "Backup requested. It can take up to several minutes for " +
          "the backup process to finish and the backup to show up in backups list.")
      invoke(@backup, :create)
    end
  end

  describe "restore" do
    before do
      @client.stub(:database_backup).and_return({"filename" => "better.tar.gz", "size" => 12345, "kind" => "postgre"})
      @client.stub(:restore_backup).and_return({"filename" => "better.tar.gz", "size" => 12345, "kind" => "postgre"})
      $stdout.stub(:puts)
    end

    it "should ensure user has logged in" do
      hooks(@backup, :restore).should include(:logged_in?)
    end

    it "should restore database" do
      $stdout.should_receive(:puts).with("You are about restore database postgre for cloud foo-staging to state from better.tar.gz")
      $stdout.should_receive(:print).with("I want to restore the database (yes/no): ")
      $stdout.should_receive(:puts).with("\n")
      @client.stub(:restore_backup).with("todo-list-test","better.tar.gz")
      $stdout.should_receive(:puts).with("\n")
      $stdout.should_receive(:puts).with("Restore has been scheduled. Wait few minutes till database is restored.")

      fake_stdin(["yes"]) do
        invoke(@backup, :restore, "better.tar.gz")
      end
    end

    context "on type no" do
      it "should cancel restore database" do
        $stdout.should_receive(:puts).with("You are about restore database postgre for cloud foo-staging to state from better.tar.gz")
        $stdout.should_receive(:print).with("I want to restore the database (yes/no): ")
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:puts).with(red "Canceled")

        lambda {
          fake_stdin(["no"]) do
            invoke(@backup, :restore, "better.tar.gz")
          end
        }.should raise_error(SystemExit)
      end
    end

    it "should exit with 1 when filename is not specified" do
      $stdout.should_receive(:puts).with(red "Filename is required")
      lambda {
        invoke(@backup, :restore)
      }.should raise_error(SystemExit)
    end

    context "on backup not found" do
      it "should display error message" do
        response = {"resource" => "database_backup"}
        exception = Shelly::Client::NotFoundException.new(response)
        @client.stub(:database_backup).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Backup not found")
        $stdout.should_receive(:puts).with("You can list available backups with `shelly backup list` command")
        invoke(@backup, :restore, "better.tar.gz")
      end
    end
  end
end
