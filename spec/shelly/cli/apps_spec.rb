require "spec_helper"
require "shelly/cli/apps"

describe Shelly::CLI::Apps do
  before do

  end

  describe "#add" do
    it "should ask user how he will use application"

    it "should use purpose provided by user"
    context "when user provided empty purpose" do
      it "should use 'production' as default"
    end

    it "should use code name provided by user"
    context "when user provided empty code name" do
      it "should use 'current_dirname-purpose' as default"
    end

    it "should use database provided by user"
    context "when user provided empty database" do
      it "should use 'postgresql' database as default"
    end

    it "should add git remote"

    it "should create Cloudfile"

    it "should browser window with link to edit billing information"

    it "should display info about adding Cloudfile to repository"
    it "should display info on how to deploy to ShellyCloud"

  end
end