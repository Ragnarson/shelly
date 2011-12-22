require "spec_helper"
require "shelly/cli/backup"

describe Shelly::CLI::Backup do
  before do
    @backup = Shelly::CLI::Backup.new
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
  end

  describe "#list" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
      @client.stub(:token).and_return("abc")
    end

    it "should exit with message if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with("\e[31mNo Cloudfile found\e[0m")
      lambda {
        @backup.list
      }.should raise_error(SystemExit)
    end

    it "should exit if user doesn't have access to cloud in Cloudfile" do
      response = {"message" => "Cloud foo-staging not found"}
      exception = Shelly::Client::APIError.new(response.to_json)
      @client.stub(:database_backups).and_raise(exception)
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-staging' cloud defined in Cloudfile")
      lambda { @backup.list }.should raise_error(SystemExit)
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
        lambda { @backup.list }.should raise_error(SystemExit)
      end

      it "should take cloud from command line for which to show backups" do
        @client.should_receive(:database_backups).with("foo-staging").and_return([{"filename" => "backup.postgre.tar.gz", "size" => "10kb"},{"filename" => "backup.mongo.tar.gz", "size" => "22kb"}])
        $stdout.should_receive(:puts).with(green "Available backups:")
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:puts).with("  Filename               |  Size")
        $stdout.should_receive(:puts).with("  backup.postgre.tar.gz  |  10kb")
        $stdout.should_receive(:puts).with("  backup.mongo.tar.gz    |  22kb")
        @backup.options = {:cloud => 'foo-staging'}
        @backup.list
      end
    end
  end
end
