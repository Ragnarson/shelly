require "spec_helper"
require "shelly/cli/organization"

describe Shelly::CLI::Organization do
  before do
    FileUtils.stub(:chmod)
    @cli = Shelly::CLI::Organization.new
    Shelly::CLI::Organization.stub(:new).and_return(@cli)
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
      hooks(@cli, :list).should include(:logged_in?)
    end

    it "should print out all organizations with apps" do
      $stdout.should_receive(:puts).with(green("You have access to the following organizations and clouds:"))
      $stdout.should_receive(:puts).with(green("aaa"))
      $stdout.should_receive(:puts).with(/app1 \s+ |  running/)
      $stdout.should_receive(:puts).with(green("ccc"))
      $stdout.should_receive(:puts).with(/app2 \s+ |  turned off/)
      $stdout.should_receive(:puts).with(/app3 \s+ |  no code/)
      invoke(@cli, :list)
    end
  end

  describe "#add" do
    before do
      @organization = Shelly::Organization.new
      Shelly::Organization.stub(:new).and_return(@organization)
      @organization.stub(:create)
    end

    it "should ensure user has logged in" do
      hooks(@cli, :add).should include(:logged_in?)
    end

    it "should create new organization" do
      @organization.should_receive(:create)
      $stdout.should_receive(:print).with("Organization name (foo - default): ")
      $stdout.should_receive(:puts).with(green "Organization 'org-name' created")
      fake_stdin("org-name") do
        invoke(@cli, :add)
      end
    end

    it "should accept redeem-code option" do
      @organization.should_receive(:redeem_code=).with("discount")
      @cli.options = {"redeem-code" => "discount"}
      fake_stdin("org-name") do
        invoke(@cli, :add)
      end
    end

    context "on failure" do
      it "should display validation errors" do
        body = {"message" => "Validation Failed", "errors" =>
          [["name", "has been already taken"]]}
        exception = Shelly::Client::ValidationException.new(body)
        @organization.should_receive(:create).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Name has been already taken")
        lambda {
          fake_stdin("org-name") do
            invoke(@cli, :add)
          end
        }.should raise_error(SystemExit)
      end
    end
  end
end
