require "spec_helper"
require "shelly/cli/user"
require "shelly/cli/organization"

describe Shelly::CLI::User do
  before do
    FileUtils.stub(:chmod)
    @cli_user = Shelly::CLI::User.new
    Shelly::CLI::User.stub(:new).and_return(@cli_user)
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    $stdout.stub(:puts)
    $stdout.stub(:print)
    @client.stub(:token).and_return("abc")
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @app = Shelly::App.new("foo-staging")
    File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }

    @client.stub(:members).and_return({})
  end

  describe "#help" do
    it "should show help" do
      $stdout.should_receive(:puts).with("Tasks:")
      $stdout.should_receive(:puts).with(/add \[EMAIL\]\s+# Add new developer to organization/)
      $stdout.should_receive(:puts).with(/list\s+# List users with access to organizations/)
      $stdout.should_receive(:puts).with(/delete \[EMAIL\]\s+# Remove developer from organization/)
      invoke(@cli_user, :help)
    end
  end

  describe "#list" do
    let(:organizations) {
      [{"name" => "org1"}, {"name" => "org2"}]
    }

    let(:org1_members) {
      [{'email' => 'user-org1@example.com', 'active' => true, "owner" => true},
      {'email' => 'user2-org1@example2.com', 'active' => true, "owner" => false},
      {'email' => 'user3-org1@example3.com', 'active' => false, "owner" => true}]
    }

    let(:org2_members) {
      [{'email' => 'user-org2@example.com', 'active' => true, "owner" => true},
      {'email' => 'user2-org2@example2.com', 'active' => true, "owner" => false},
      {'email' => 'user3-org2@example3.com', 'active' => false, "owner" => true}]
    }

    before do
      @client.stub(:members).with("org1").and_return(org1_members)
      @client.stub(:members).with("org2").and_return(org2_members)
      @client.stub(:organizations).and_return(organizations)
    end

    it "should ensure user has logged in" do
      hooks(@cli_user, :list).should include(:logged_in?)
    end

    context "without --organization option" do
      it "displays all organizations' users" do
        $stdout.should_receive(:puts).with(green "org1")
        $stdout.should_receive(:puts).with(/user-org1@example.com\s+ \| owner/)
        $stdout.should_receive(:puts).with(/user2-org1@example2.com\s+ \| member/)
        $stdout.should_receive(:puts).with(/user3-org1@example3.com \(invited\)\s+ \| owner/)
        $stdout.should_receive(:puts).with("\n").twice
        $stdout.should_receive(:puts).with(green "org2")
        $stdout.should_receive(:puts).with(/user-org2@example.com\s+ \| owner/)
        $stdout.should_receive(:puts).with(/user2-org2@example2.com\s+ \| member/)
        $stdout.should_receive(:puts).with(/user3-org2@example3.com \(invited\)\s+ \| owner/)
        invoke(@cli_user, :list)
      end
    end

    context "with --organization option" do
      context "when given organization exists" do
        it "displays organization's users" do
          organization = Shelly::Organization.new("name" => "org1")
          Shelly::Organization.should_receive(:new).with("name" => "org1").
            and_return(organization)
          organization.stub(:members => org1_members)
          @cli_user.options = {:organization => "org1"}
          $stdout.should_receive(:puts).with(green "org1")
          $stdout.should_receive(:puts).with(/user-org1@example.com\s+ \| owner/)
          $stdout.should_receive(:puts).with(/user2-org1@example2.com\s+ \| member/)
          $stdout.should_receive(:puts).with(/user3-org1@example3.com \(invited\)\s+ \| owner/)
          invoke(@cli_user, :list)
        end
      end

      context "when given organization doesn't exist" do
        it "shows an error" do
          @cli_user.options = {:organization => "org3"}
          not_found = Shelly::Client::NotFoundException.new(
            {"resource" => "organization"})
          Shelly::Organization.should_receive(:new).with("name" => "org3").
            and_raise(not_found)

          $stdout.should_receive(:puts).with(red "Organization 'org3' not found")
          $stdout.should_receive(:puts).with(red "You can list organizations you have access to with `shelly organization list`")
          lambda do
            invoke(@cli_user, :list)
          end.should raise_error(SystemExit)
        end
      end
    end
  end

  describe "#add" do
    before do
      @organization = Shelly::Organization.new("name" => "foo-org")
      Shelly::Organization.stub(:new).and_return(@organization)
      @cli_user.options = {:organization => "foo-org"}
    end

    it "should ensure user has logged in" do
      hooks(@cli_user, :add).should include(:logged_in?)
    end

    context "on success" do
      before do
        @client.should_receive(:send_invitation).with("foo-org", "megan@example.com", true)
      end

      it "should ask about email" do
        $stdout.should_receive(:puts).with(green "Sending invitation to megan@example.com to work on foo-org organization")
        fake_stdin(["megan@example.com", "yes"]) do
          invoke(@cli_user, :add)
        end
      end

      it "should use email from argument" do
        $stdout.should_receive(:puts).with(green "Sending invitation to megan@example.com to work on foo-org organization")
        fake_stdin(["yes"]) do
          invoke(@cli_user, :add, "megan@example.com")
        end
      end
    end

    context "on failure" do
      it "should list all user's organizations" do
        @cli_user.options = {}
        $stdout.should_receive(:puts).with(red "You have to specify organization")
        $stdout.should_receive(:puts).with("Select organization using `shelly user add [EMAIL] --organization ORGANIZATION_NAME`")
        Shelly::CLI::Organization.stub_chain(:new, :list)
        lambda do
          invoke(@cli_user, :add, "megan@example.com")
        end.should raise_error(SystemExit)
      end

      it "should display forbidden exception" do
        exception = Shelly::Client::ForbiddenException.new({})
        @client.stub(:send_invitation).and_raise(exception)
        $stdout.should_receive(:puts).with(red "You have to be organization's owner to add new members")

        lambda do
          fake_stdin(["yes"]) { invoke(@cli_user, :add, "megan@example.com") }
        end.should raise_error(SystemExit)
      end

      it "should display not found" do
        response = {"resource" => "organization"}
        exception = Shelly::Client::NotFoundException.new(response)
        @client.stub(:send_invitation).and_raise(exception)

        $stdout.should_receive(:puts).with(red "Organization 'foo-org' not found")
        $stdout.should_receive(:puts).with(red "You can list organizations you have access to with `shelly organization list`")
        lambda do
          fake_stdin(["yes"]) { invoke(@cli_user, :add, "megan@example.com") }
        end.should raise_error(SystemExit)
      end

      it "should display validation exception" do
        body = {"message" => "Validation Failed", "errors" => [["email", "megan@example.com has been already taken"]]}
        exception = Shelly::Client::ValidationException.new(body)
        @client.stub(:send_invitation).and_raise(exception)
        $stdout.should_receive(:puts).with(red "User megan@example.com is already in the organization foo-org")

        lambda do
          fake_stdin(["yes"]) { invoke(@cli_user, :add, "megan@example.com") }
        end.should raise_error(SystemExit)
      end
    end
  end

  describe "#delete" do
    before do
      @organization = Shelly::Organization.new("name" => "foo-org")
      Shelly::Organization.stub(:new).and_return(@organization)
      @cli_user.options = {:organization => "foo-org"}
    end

    it "should ensure user has logged in" do
      hooks(@cli_user, :delete).should include(:logged_in?)
    end

    context "on success" do
      it "should ask about email" do
        @client.should_receive(:delete_member).with("foo-org", "megan@example.com")
        fake_stdin(["megan@example.com"]) do
          invoke(@cli_user, :delete)
        end
      end

      it "should receive email from param" do
        @client.should_receive(:delete_member).with("foo-org", "megan@example.com")
        invoke(@cli_user, :delete, "megan@example.com")
      end

      it "should show that user was removed" do
        @client.stub(:delete_member)
        $stdout.should_receive(:puts).with("User megan@example.com deleted from organization foo-org")
        invoke(@cli_user, :delete, "megan@example.com")
      end
    end

    context "on failure" do
      it "should show that user wasn't found" do
        exception = Shelly::Client::NotFoundException.new("resource" => "user")
        @client.stub(:delete_member).and_raise(exception)
        $stdout.should_receive(:puts).with(red "User 'megan@example.com' not found")
        $stdout.should_receive(:puts).with(red "You can list users with `shelly user list`")
        lambda {
          invoke(@cli_user, :delete, "megan@example.com")
        }.should raise_error(SystemExit)
      end

      it "should show that organization wasn't found" do
        exception = Shelly::Client::NotFoundException.new("resource" => "organization")
        @client.stub(:delete_member).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Organization 'foo-org' not found")
        $stdout.should_receive(:puts).with(red "You can list organizations you have access to with `shelly organization list`")
        lambda {
          invoke(@cli_user, :delete, "megan@example.com")
        }.should raise_error(SystemExit)
      end

      it "should show that user can't delete own collaboration" do
        exception = Shelly::Client::ConflictException.new("message" =>
          "Can't remove own collaboration")
        @client.stub(:delete_member).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Can't remove own collaboration")
        lambda {
          invoke(@cli_user, :delete, "megan@example.com")
        }.should raise_error(SystemExit)
      end

      it "should show forbidden exception" do
        exception = Shelly::Client::ForbiddenException.new({})
        @client.stub(:delete_member).and_raise(exception)
        $stdout.should_receive(:puts).with(red "You have to be organization's owner to remove members")

        lambda {
          invoke(@cli_user, :delete, "megan@example.com")
        }.should raise_error(SystemExit)
      end
    end
  end
end
