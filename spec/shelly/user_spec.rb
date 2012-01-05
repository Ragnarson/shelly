require "spec_helper"

describe Shelly::User do
  before do
    FileUtils.mkdir_p("~/.ssh")
    File.open("~/.ssh/id_rsa.pub", "w") { |f| f << "ssh-key AAbbcc" }
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @user = Shelly::User.new("bob@example.com", "secret")
    @user.stub(:set_credentials_permissions)
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
    end

    it "should register user at Shelly Cloud" do
      @client.should_receive(:register_user).with("bob@example.com", "secret", "ssh-key AAbbcc")
      @user.register
    end

    it "should save credentials after successful registration" do
      @user.should_receive(:save_credentials)
      @user.register
    end

    context "when ssh key is not available" do
      it "should register without it" do
        FileUtils.rm_rf("~/.ssh/id_rsa.pub")
        @client.should_receive(:register_user).with("bob@example.com", "secret", nil)
        @user.register
      end
    end
  end

  describe "#token" do
    it "should return token" do
      @client.should_receive(:token).and_return({"token" => "abc"})
      @user.token.should == "abc"
    end
  end

  describe "#save_credentials" do
    it "should save credentials to file" do
      File.exists?("~/.shelly/credentials").should be_false
      @user.save_credentials
      File.read("~/.shelly/credentials").should == "bob@example.com\nsecret"
    end

    it "should create config_dir if it doesn't exist" do
      File.exists?("~/.shelly").should be_false
      @user.save_credentials
      File.exists?("~/.shelly").should be_true
    end

    it "should set proper permissions on config_dir and credentials file" do
      user = Shelly::User.new("bob@example.com", "secret")
      FileUtils.should_receive(:chmod).with(0700, File.expand_path("~/.shelly"))
      FileUtils.should_receive(:chmod).with(0600, File.expand_path("~/.shelly/credentials"))
      user.save_credentials
    end
  end

  describe "#delete_credentials" do
    it "should delete credentials from file" do
      @user.save_credentials
      File.exists?("~/.shelly/credentials").should be_true
      File.read("~/.shelly/credentials").should == "bob@example.com\nsecret"
      @user.delete_credentials
      File.exists?("~/.shelly/credentials").should be_false
    end
  end

  describe "#load_credentials" do
    it "should load credentials from file" do
      config_dir = File.expand_path("~/.shelly")
      FileUtils.mkdir_p(config_dir)
      File.open(File.join(config_dir, "credentials"), "w") { |f| f << "superman@example.com\nkal-el" }

      user = Shelly::User.new
      user.load_credentials
      user.email.should == "superman@example.com"
      user.password.should == "kal-el"
    end

    context "credentials file doesn't exist" do
      it "should return nil" do
        user = Shelly::User.new
        user.load_credentials.should be_nil
        user.email.should be_nil
        user.password.should be_nil
      end
    end
  end

  describe "#send_invitation" do
    it "should send invitation" do
      @client.should_receive(:send_invitation).with("foo-staging", "megan@example.com")
      @user.send_invitation("foo-staging", "megan@example.com")
    end
  end

  describe "#ssh_key_path" do
    it "should return path to public ssh key file" do
      @user.ssh_key_path.should == File.expand_path("~/.ssh/id_rsa.pub")
    end
  end

  describe "#ssh_key_exists?" do
    it "should return true if key exists, false otherwise" do
      @user.should be_ssh_key_exists
      FileUtils.rm_rf("~/.ssh/id_rsa.pub")
      @user.should_not be_ssh_key_exists
    end
  end

  describe "#ssh_key_registered?" do
    it "should read and check if ssh key exists in database" do
      @client.should_receive(:ssh_key_available?).with('ssh-key AAbbcc')
      @user.ssh_key_registered?
    end
  end

  describe "#delete_ssh_key" do
    it "should invoke logout when ssh key exists" do
      @client.should_receive(:logout).with('ssh-key AAbbcc')
      @user.delete_ssh_key
    end

    it "should not invoke logout when ssh key doesn't exist" do
      FileUtils.rm_rf("~/.ssh/id_rsa.pub")
      @client.should_not_receive(:logout)
      @user.delete_ssh_key
    end
  end

  describe "#upload_ssh_key" do
    it "should read and upload user's public SSH key" do
      @client.should_receive(:add_ssh_key).with("ssh-key AAbbcc")
      @user.upload_ssh_key
    end
  end

  describe "#login" do
    before do
      @client.stub(:token)
    end

    it "should try to login with given credentials" do
      @client.should_receive(:token)
      @user.login
    end

    context "on successful authentication" do
      it "should save user's credentials" do
        @user.should_receive(:save_credentials)
        @user.login
      end
    end

    context "on unsuccessful authentication" do
      it "should not save credentials" do
        @client.stub(:token).and_raise(RestClient::Unauthorized.new)
        @client.should_not_receive(:save_credentials)
        lambda {
          @user.login
        }.should raise_error
      end
    end
  end

  describe "#apps" do
    it "should fetch list of apps via API client" do
      @client.should_receive(:apps)
      @user.apps
    end
  end
end

