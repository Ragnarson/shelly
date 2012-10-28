require "spec_helper"
require "shelly/organization"

describe Shelly::Organization do
  before do
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @organization = Shelly::Organization.new({"name" => "foo-org",
      "app_code_names" => ['foo-staging']})
  end

  describe "#apps" do
    it "should initialize App objects" do
      Shelly::App.should_receive(:new).with('foo-staging')
      @organization.apps
    end
  end
end
