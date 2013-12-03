require "spec_helper"
require "shelly/ssh_key"

describe Shelly::SshKey do
  let(:ssh_key) { Shelly::SshKey.new("~/.ssh/id_rsa.pub") }
  let(:fingerprint) { "f6:08:b8:46:df:6d:b2:86:48:ae:e5:7c:25:ef:cf:ad" }
  before do
    ssh_key.stub(:fingerprint => fingerprint)
    FileUtils.mkdir_p("~/.ssh")
    File.open(ssh_key.path, "w") { |f| f << "ssh-rsa AAAAB3NzaC1" }
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
  end

  describe "#destroy?" do
    it "should destroy key via API if it's uploaded" do
      @client.should_receive(:ssh_key).with(fingerprint).and_return(true)
      @client.should_receive(:delete_ssh_key).with(fingerprint)
      ssh_key.destroy
    end

    context "key doesn't exist" do
      it "should not try to destroy it" do
        FileUtils.rm_rf(ssh_key.path)
        @client.should_not_receive(:delete_ssh_key)
        ssh_key.destroy
      end
    end

    context "key isn't uploaded" do
      it "should not try to destroy it" do
        @client.should_receive(:ssh_key).with(fingerprint).
          and_raise(Shelly::Client::NotFoundException.new)
        @client.should_not_receive(:delete_ssh_key)
        ssh_key.destroy
      end
    end
  end

  describe "#uploaded?" do
    context "key exists for this user on Shelly" do
      it "should return true" do
        @client.stub(:ssh_key => {})
        ssh_key.should be_uploaded
      end
    end

    context "key doesn't exist on Shelly" do
      it "should return true if key exists in Shelly" do
        ex = Shelly::Client::NotFoundException.new
        @client.stub(:ssh_key).and_raise(ex)
        ssh_key.should_not be_uploaded
      end
    end
  end
end
