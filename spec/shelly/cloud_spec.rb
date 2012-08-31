require "spec_helper"
require "shelly/cloudfile"
require "shelly/cloud"

describe Shelly::Cloud do
  before do
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @cloud = Shelly::Cloud.new("code_name" => "foo-staging", "content" => {})
  end

  describe "#databases" do
    before do
      content = {"servers" => {"app1" => {"databases" => ["postgresql", "redis"]},
                               "app2" => {"databases" => ["mongodb"]}}}
      @cloud.stub(:content).and_return(content)
    end

    it "should return databases in cloudfile" do
      @cloud.databases.should =~ ['redis', 'mongodb', 'postgresql']
    end

    it "should return databases except for redis" do
      @cloud.backup_databases.should =~ ['postgresql', 'mongodb']
    end
  end

  describe "#delayed_job?" do
    it "should return true if present" do
      content = {"servers" => {"app1" => {"delayed_job" => 1}}}
      @cloud.stub(:content).and_return(content)
      @cloud.delayed_job?.should be_true
    end

    it "should retrun false if not present" do
      content = {"servers" => {"app1" => {"size" => "small"}}}
      @cloud.stub(:content).and_return(content)
      @cloud.delayed_job?.should be_false
    end
  end

  describe "#whenever?" do
    it "should return true if present" do
      content = {"servers" => {"app1" => {"whenever" => true}}}
      @cloud.stub(:content).and_return(content)
      @cloud.whenever?.should be_true
    end

    it "should return false if not present" do
      content = {"servers" => {"app1" => {"size" => "small"}}}
      @cloud.stub(:content).and_return(content)
      @cloud.whenever?.should be_false
    end
  end
end
