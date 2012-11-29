require "spec_helper"
require "shelly/backup"

describe Shelly::Backup do
  before do
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
  end

  it "should assign attributes" do
    backup = Shelly::Backup.new(attributes)

    backup.code_name.should == "foo"
    backup.filename.should == "backup.tar.gz"
    backup.human_size.should == "2KB"
    backup.size.should == 2048
    backup.state.should == "completed"
  end

  describe "#download" do
    it "should download given backup via API file with filename to which backup will be downloaded" do
      callback = lambda {}
      @client.should_receive(:download_backup).with("foo", "backup.tar.gz", callback)
      backup = Shelly::Backup.new(attributes)
      backup.download(callback)
    end
  end

  describe "#in_progress?" do
    it "should return true backup is in in_progress state" do
      backup = Shelly::Backup.new(attributes("state" => "in_progress"))
      backup.in_progress?.should be_true
    end

    it "should return true backup is in pending state" do
      backup = Shelly::Backup.new(attributes("state" => "pending"))
      backup.in_progress?.should be_true
    end

    it "should return false backup is in other state" do
      backup = Shelly::Backup.new(attributes)
      backup.in_progress?.should be_false
    end
  end


  def attributes(options = {})
    {"code_name" => "foo",
    "filename"   => "backup.tar.gz",
    "human_size" => "2KB",
    "size"       => 2048,
    "state"      => "completed"}.merge(options)
  end
end
