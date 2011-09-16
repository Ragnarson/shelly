require "spec_helper"
require "shelly/app"

describe Shelly::App do
  describe ".guess_code_name" do
    before do
      FileUtils.mkdir_p("/projects/foo")
    end

    it "should return name of current working directory" do
      Dir.chdir("/projects/foo")
      Shelly::App.guess_code_name.should == "foo"
    end
  end
end
