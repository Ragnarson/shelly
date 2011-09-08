require "spec_helper"

describe "CLI" do
  describe "shelly version (-v, --version)" do
    it "should display shelly's version" do
      %w(version -v --version).each do |cmd|
        shelly(cmd).should == "shelly version #{Shelly::VERSION}"
      end
    end
  end
end
