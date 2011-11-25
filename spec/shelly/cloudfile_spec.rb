require "spec_helper"
require "shelly/cloudfile"

describe Shelly::Cloudfile do
  before do
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @hash = {:code_name => {:code => "test"}}
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @cloudfile = Shelly::Cloudfile.new
  end

  describe "#hash converting" do
    it "should convert hash to proper string" do
      @cloudfile.yaml(@hash).should == "code_name:\n  code: test"
    end

    it "should convert a hash to yaml format" do
      @cloudfile.write(@hash)
      @cloudfile.open.should == {"code_name" => {"code" => "test"}}
    end
  end

  describe "#fetch_users" do
    it "should return array to display with clouds and users" do
      @cloudfile.write(@hash)
      @client.should_receive(:apps_users).and_return(response)
      response = @cloudfile.fetch_users
      response.should == {"foo-staging" => ["user@example.com"]}
    end

    def response
      [{'code_name' => 'foo-staging','users' => [{'email' => 'user@example.com'}]}]
    end
  end

end
