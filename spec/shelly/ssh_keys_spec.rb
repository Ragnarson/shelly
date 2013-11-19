require "spec_helper"
require "shelly/ssh_keys"

describe Shelly::SshKeys do
  let(:keys) { Shelly::SshKeys.new }
  before { FileUtils.mkdir_p('~/.ssh') }
  describe "#prefered_key" do
    context "dsa key exists" do
      before { FileUtils.touch("~/.ssh/id_dsa.pub") }
      it "should return dsa key" do
        keys.prefered_key.path.should match(/dsa/)
      end
    end
    context "dsa key doesn't exists" do
      it "should return rsa key" do
        keys.prefered_key.path.should match(/rsa/)
      end
    end
  end
end
