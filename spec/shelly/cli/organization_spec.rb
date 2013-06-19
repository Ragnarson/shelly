require "spec_helper"
require "shelly/cli/organization"

describe Shelly::CLI::Organization do
  before do
  FileUtils.stub(:chmod)
  @organization = Shelly::CLI::Organization.new
  Shelly::CLI::Organization.stub(:new).and_return(@organization)
  @client = mock
  Shelly::Client.stub(:new).and_return(@client)
  $stdout.stub(:puts)
  $stdout.stub(:print)
  @client.stub(:authorize!)
  FileUtils.mkdir_p("/projects/foo")
  Dir.chdir("/projects/foo")
  end

  describe "#list" do
    before do
      @client.stub(:token).and_return("abc")
      @client.stub(:organizations).and_return([
        {"name" => "aaa", "app_code_names" => ["app1"]},
        {"name" => "ccc", "app_code_names" => ["app2", "app3"]}
      ])
      @client.stub(:app).with("app1").and_return("state" => "running")
      @client.stub(:app).with("app2").and_return("state" => "turned_off")
      @client.stub(:app).with("app3").and_return("state" => "no_code")
    end

    it "should ensure user has logged in" do
      hooks(@organization, :list).should include(:logged_in?)
    end

    it "should print out all organizations with apps" do
      $stdout.should_receive(:puts).with(green("You have access to the following organizations and clouds:"))
      $stdout.should_receive(:puts).with(green("aaa"))
      $stdout.should_receive(:puts).with(/app1 \s+ |  running/)
      $stdout.should_receive(:puts).with(green("ccc"))
      $stdout.should_receive(:puts).with(/app2 \s+ |  turned off/)
      $stdout.should_receive(:puts).with(/app3 \s+ |  no code/)
      invoke(@organization, :list)
    end
  end
end
