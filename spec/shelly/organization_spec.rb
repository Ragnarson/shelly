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

  describe "#memberships" do
    before do
      response = [{"email" => "bb@example.com", "active" => true, "owner" => true},
                  {"email" => "aa@example.com", "active" => true, "owner" => false},
                  {"email" => "cc@example.com", "active" => false, "owner" => true},
                  {"email" => "dd@example.com", "active" => false, "owner" => false}]
      @client.stub(:members).with("foo-org").and_return(response)
    end

    it "should fetch organization's users" do
      @client.should_receive(:members).with("foo-org")
      @organization.memberships
    end

    it "should sort members by email" do
      members = @organization.memberships
      members.should == [{"email"=>"aa@example.com", "active"=>true, "owner"=>false},
                         {"email"=>"bb@example.com", "active"=>true, "owner"=>true},
                         {"email"=>"cc@example.com", "active"=>false, "owner"=>true},
                         {"email"=>"dd@example.com", "active"=>false, "owner"=>false}]
    end


    context "owners" do
      it "should return only owners without inactive members" do
        owners = @organization.owners
        owners.should == [{"email"=>"bb@example.com", "active"=>true, "owner"=>true}]
      end
    end

    context "members" do
      it "should return only members without inactive members" do
        members = @organization.members
        members.should == [{"email"=>"aa@example.com", "active"=>true, "owner"=>false}]
      end
    end

    context "inactive_members" do
      it "should return only inactive members" do
        inactive = @organization.inactive_members
        inactive.should == [{"email"=>"cc@example.com", "active"=>false, "owner"=>true},
                           {"email"=>"dd@example.com", "active"=>false, "owner"=>false}]
      end
    end
  end

  describe "#create" do
    it "should create organization via API client" do
      @client.should_receive(:create_organization).with(
        :name => "new-organization", :redeem_code => "discount")
      @organization.name = "new-organization"
      @organization.redeem_code = "discount"
      @organization.create
    end
  end

  describe "#send_invitation" do
    it "should send invitation" do
      @client.should_receive(:send_invitation).with("foo-org", "megan@example.com", true)
      @organization.send_invitation("megan@example.com", true)
    end
  end

  describe "#delete_member" do
    it "should delete collaboration" do
      @client.should_receive(:delete_member).with("foo-org", "megan@example.com")
      @organization.delete_member("megan@example.com")
    end
  end
end
