require "spec_helper"

describe Shelly::User do
  let(:email) { "bob@example.com" }
  let(:password) { "secret" }

  before do
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @user = Shelly::User.new
  end

  describe ".guess_email" do
    it "should return user email fetched from git config" do
      io = mock(:read => "boby@example.com\n")
      IO.should_receive(:popen).with("git config --get user.email").and_return(io)
      Shelly::User.guess_email.should == "boby@example.com"
    end
  end

  describe "#register" do
    before do
      @client.stub(:register_user)
      @client.stub(:authorize_with_email_and_password)
    end

    it "should register user at Shelly Cloud" do
      @client.should_receive(:register_user).with(email, password)
      @user.register(email, password)
    end
  end

  describe "#delete_credentials" do
    it "should delete credentials from file" do
      FileUtils.mkdir_p("~/.shelly")
      File.open("~/.shelly/credentials", "w") { |f| f << "bob@example.com\nsecret" }
      @user.delete_credentials
      File.exists?("~/.shelly/credentials").should be_false
    end
  end

  describe "#login" do
    before do
      @client.stub(:authorize_with_email_and_password)
    end

    it "should try to login with given credentials" do
      @client.should_receive(:authorize_with_email_and_password).
        with(email, password)
      @user.login(email, password)
    end

    it "should remove legacy credentials" do
      @user.should_receive(:delete_credentials)
      @user.login(email, password)
    end
  end

  describe "#authorize!" do
    it "should authorize via client" do
      @client.should_receive(:authorize!)
      @user.authorize!
    end

    context "when old credentials file exists" do
      before do
        FileUtils.mkdir_p("~/.shelly")
        File.open("~/.shelly/credentials", "w") { |f| f << "bob@example.com\nsecret" }
      end

      it "should authorize using email and password from that file" do
        @client.should_receive(:authorize_with_email_and_password).
          with("bob@example.com", "secret")
        @user.authorize!
      end

      it "should remove the file after authorization" do
        @client.stub(:authorize_with_email_and_password)
        @user.authorize!
        File.exists?("~/.shelly/credentials").should be_false
      end
    end
  end

  describe "#apps" do
    it "should fetch list of apps via API client" do
      @client.should_receive(:apps).and_return([])
      @user.apps
    end
  end

  describe "#organizations" do
    it "should initialaize organizations objects" do
      organizations = [{"name" => "org1"}]
      @client.should_receive(:organizations).and_return(organizations)
      Shelly::Organization.should_receive(:new).with({"name" => "org1"})
      @user.organizations
    end
  end
end
