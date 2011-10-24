require "spec_helper"
require "shelly/cli/main"

describe Shelly::CLI::Main do
  before do
    ENV['SHELLY_GIT_HOST'] = nil
    FileUtils.stub(:chmod)
    @main = Shelly::CLI::Main.new
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    Shelly::User.stub(:guess_email).and_return("")
    $stdout.stub(:puts)
    $stdout.stub(:print)
  end

  describe "#version" do
    it "should return shelly's version" do
      $stdout.should_receive(:puts).with("shelly version #{Shelly::VERSION}")
      @main.version
    end
  end

  describe "#help" do
    it "should display available commands" do
      expected = <<-OUT
Tasks:
  shelly add               # Adds new application to Shelly Cloud
  shelly help [TASK]       # Describe available tasks or one specific task
  shelly login [EMAIL]     # Logins user to Shelly Cloud
  shelly register [EMAIL]  # Registers new user account on Shelly Cloud
  shelly users <command>   # Manages users using this app
  shelly version           # Displays shelly version
OUT
      out = IO.popen("bin/shelly").read.strip
      out.should == expected.strip
    end
  end

  describe "#register" do
    before do
      @client.stub(:register_user)
      @key_path = File.expand_path("~/.ssh/id_rsa.pub")
      @user = Shelly::User.new
      @user.stub(:ssh_key_registered?)
      Shelly::User.stub(:new).and_return(@user)
    end

    it "should check ssh key in database" do
      @user.stub(:ssh_key_registered?).and_raise(RestClient::Conflict)
      $stdout.should_receive(:puts).with("User with your ssh key already exists.")
      $stdout.should_receive(:puts).with("You can login using: shelly login [EMAIL]")
      lambda {
        @main.register
      }.should raise_error(SystemExit)
    end

    it "should ask for email, password and password confirmation" do
      $stdout.should_receive(:print).with("Email: ")
      $stdout.should_receive(:print).with("Password: ")
      $stdout.should_receive(:print).with("Password confirmation: ")
      fake_stdin(["better@example.com", "secret", "secret"]) do
        @main.register
      end
    end

    it "should suggest email and use it if user enters blank email" do
      Shelly::User.stub(:guess_email).and_return("kate@example.com")
      $stdout.should_receive(:print).with("Email (kate@example.com - default): ")
      @client.should_receive(:register_user).with("kate@example.com", "secret", nil)
      fake_stdin(["", "secret", "secret"]) do
        @main.register
      end
    end

    it "should use email provided by user" do
      @client.should_receive(:register_user).with("better@example.com", "secret", nil)
      fake_stdin(["better@example.com", "secret", "secret"]) do
        @main.register
      end
    end

    it "should not ask about email if it's provided as argument" do
      $stdout.should_receive(:puts).with("Registering with email: kate@example.com")
      fake_stdin(["secret", "secret"]) do
        @main.register("kate@example.com")
      end
    end

    context "when user enters blank email" do
      it "should show error message and exit with 1" do
        Shelly::User.stub(:guess_email).and_return("")
        $stdout.should_receive(:puts).with("Email can't be blank, please try again")
        lambda {
          fake_stdin(["", "bob@example.com", "only-pass", "only-pass"]) do
            @main.register
          end
        }.should raise_error(SystemExit)
      end
    end

    context "when user enters blank password" do
      it "should ask for it again" do
        $stdout.should_receive(:puts).with("Password can't be blank")
        fake_stdin(["better@example.com", "", "", "secret", "secret"]) do
          @main.register
        end
      end
    end

    context "when user enters password and password confirmation which don't match each other" do
      it "should ask for them again" do
        $stdout.should_receive(:puts).with("Password and password confirmation don't match, please type them again")
        fake_stdin(["better@example.com", "secret", "sec-TYPO-ret", "secret", "secret"]) do
          @main.register
        end
      end
    end

    context "public SSH key exists" do
      it "should register with the public SSH key" do
        FileUtils.mkdir_p("~/.ssh")
        File.open(@key_path, "w") { |f| f << "key" }
        $stdout.should_receive(:puts).with("Uploading your public SSH key from #{@key_path}")
        fake_stdin(["kate@example.com", "secret", "secret"]) do
          @main.register
        end
      end
    end

    context "public SSH key doesn't exist" do
      it "should register user without the public SSH key" do
        $stdout.should_not_receive(:puts).with("Uploading your public SSH key from #{@key_path}")
        fake_stdin(["kate@example.com", "secret", "secret"]) do
          @main.register
        end
      end
    end

    context "on successful registration" do
      it "should display message about registration and email address confirmation" do
        @client.stub(:register_user).and_return(true)
        $stdout.should_receive(:puts).with("Successfully registered!")
        $stdout.should_receive(:puts).with("Check you mailbox for email address confirmation")
        fake_stdin(["kate@example.com", "pass", "pass"]) do
          @main.register
        end
      end
    end

    context "on unsuccessful registration" do
      it "should display errors and exit with 1" do
        response = {"message" => "Validation Failed", "errors" => [["email", "has been already taken"]]}
        exception = Shelly::Client::APIError.new(response.to_json)
        @client.stub(:register_user).and_raise(exception)
        $stdout.should_receive(:puts).with("email has been already taken")
        lambda {
          fake_stdin(["kate@example.com", "pass", "pass"]) do
            @main.register
          end
        }.should raise_error(SystemExit)
      end
    end
  end

  describe "#login" do
    before do
      @user = Shelly::User.new
      @user.stub(:upload_ssh_key)
      @client.stub(:token).and_return("abc")
      @client.stub(:apps).and_return([{"code_name" => "abc"}, {"code_name" => "fooo"}])
      Shelly::User.stub(:new).and_return(@user)
    end

    it "should ask about email and password" do
      fake_stdin(["megan@example.com", "secret"]) do
        @main.login
      end
    end

    context "on successful login" do
      it "should display message about successful login" do
        $stdout.should_receive(:puts).with("Login successful")
        fake_stdin(["megan@example.com", "secret"]) do
          @main.login
        end
      end

      it "should upload user's public SSH key" do
        @user.should_receive(:upload_ssh_key)
        $stdout.should_receive(:puts).with("Uploading your public SSH key")
        fake_stdin(["megan@example.com", "secret"]) do
          @main.login
        end
      end

      it "should display list of applications to which user has access" do
        $stdout.should_receive(:puts).with("\e[32mYou have following applications available:\e[0m")
        $stdout.should_receive(:puts).with("  abc")
        $stdout.should_receive(:puts).with("  fooo")
        fake_stdin(["megan@example.com", "secret"]) do
          @main.login
        end
      end
    end

    context "on unauthorized user" do
      it "should exit with 1 and display error message" do
        exception = RestClient::Unauthorized.new
        @client.stub(:token).and_raise(exception)
        $stdout.should_receive(:puts).with("Wrong email or password or your email is unconfirmend")
        lambda {
          fake_stdin(["megan@example.com", "secret"]) do
            @main.login
          end
        }.should raise_error(SystemExit)
      end
    end
  end

  describe "#add" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      @app = Shelly::App.new
      @app.stub(:add_git_remote)
      @app.stub(:create)
      @app.stub(:generate_cloudfile).and_return("Example Cloudfile")
      @app.stub(:open_billing_page)
      @app.stub(:git_url).and_return("git@git.shellycloud.com:foooo.git")
      Shelly::App.stub(:inside_git_repository?).and_return(true)
      Shelly::App.stub(:new).and_return(@app)
    end

    it "should exit with message if command run outside git repository" do
      Shelly::App.stub(:inside_git_repository?).and_return(false)
      $stdout.should_receive(:puts).with("Must be run inside your project git repository")
      lambda {
        fake_stdin(["staging", "", ""]) do
          @main.add
        end
      }.should raise_error(SystemExit)
    end

    it "should ask user how he will use application" do
      $stdout.should_receive(:print).with("How will you use this system (production - default,staging): ")
      @app.should_receive(:purpose=).with("staging")
      fake_stdin(["staging", "", ""]) do
        @main.add
      end
    end

    context "command line options" do
      context "invalid params" do
        it "should show help and exit if not all options are passed" do
          $stdout.should_receive(:puts).with("Wrong parameters. See 'shelly help add' for further information")
          @main.options = {"code_name" => "foo"}
          lambda { @main.add }.should raise_error(SystemExit)
        end

        it "should exit if databases are not valid" do
          $stdout.should_receive(:puts).with("Wrong parameters. See 'shelly help add' for further information")
          @main.options = {"code_name" => "foo", "environment" => "production", "databases" => ["not existing"], "domains" => ["foo.example.com"]}
          lambda { @main.add }.should raise_error(SystemExit)
        end
      end

      context "valid params" do
        it "should create app on shelly cloud" do
          @app.should_receive(:create)
          @main.options = {"code_name" => "foo", "environment" => "production", "databases" => ["postgresql"], "domains" => ["foo.example.com"]}
          @main.add
        end
      end
    end

    context "when user provided empty purpose" do
      it "should use 'production' as default" do
        $stdout.should_receive(:print).with("How will you use this system (production - default,staging): ")
        @app.should_receive(:purpose=).with("production")
        fake_stdin(["", "", ""]) do
          @main.add
        end
      end
    end

    it "should use code name provided by user" do
      $stdout.should_receive(:print).with("How will you use this system (production - default,staging): ")
      $stdout.should_receive(:print).with("Application code name (foo-staging - default): ")
      @app.should_receive(:code_name=).with("mycodename")
      fake_stdin(["staging", "mycodename", ""]) do
        @main.add
      end
    end

    context "when user provided empty code name" do
      it "should use 'current_dirname-purpose' as default" do
        $stdout.should_receive(:print).with("How will you use this system (production - default,staging): ")
        $stdout.should_receive(:print).with("Application code name (foo-staging - default): ")
        fake_stdin(["staging", "", ""]) do
          @main.add
        end
      end
    end

    it "should use database provided by user (separated by comma or space)" do
      $stdout.should_receive(:print).with("Which database do you want to use postgresql, mongodb, redis, none (postgresql - default): ")
      @app.should_receive(:databases=).with(["postgresql", "mongodb", "redis"])
      fake_stdin(["staging", "", "postgresql  ,mongodb redis"]) do
        @main.add
      end
    end

    it "should ask again for databases if unsupported kind typed" do
      $stdout.should_receive(:print).with("Which database do you want to use postgresql, mongodb, redis, none (postgresql - default): ")
      $stdout.should_receive(:print).with("Unknown database kind. Supported are: postgresql, mongodb, redis, none: ")
      fake_stdin(["staging", "", "postgresql,doesnt-exist", "none"]) do
        @main.add
      end
    end

    context "when user provided empty database" do
      it "should use 'postgresql' database as default" do
        @app.should_receive(:databases=).with(["postgresql"])
        fake_stdin(["staging", "", ""]) do
          @main.add
        end
      end
    end

    it "should create the app on shelly cloud" do
      @app.should_receive(:create)
      fake_stdin(["", "", ""]) do
        @main.add
      end
    end

    it "should display validation errors if they are any" do
      response = {"message" => "Validation Failed", "errors" => [["code_name", "has been already taken"]]}
      exception = Shelly::Client::APIError.new(response.to_json)
      @app.should_receive(:create).and_raise(exception)
      $stdout.should_receive(:puts).with("code_name has been already taken")
      lambda {
        fake_stdin(["", "", ""]) do
          @main.add
        end
      }.should raise_error(SystemExit)
    end

    it "should add git remote" do
      $stdout.should_receive(:puts).with("\e[32mAdding remote staging git@git.shellycloud.com:foooo.git\e[0m")
      @app.should_receive(:add_git_remote)
      fake_stdin(["staging", "foooo", ""]) do
        @main.add
      end
    end

    it "should create Cloudfile" do
      File.exists?("/projects/foo/Cloudfile").should be_false
      fake_stdin(["staging", "foooo", ""]) do
        @main.add
      end
      File.read("/projects/foo/Cloudfile").should == "Example Cloudfile"
    end

    it "should browser window with link to edit billing information" do
      $stdout.should_receive(:puts).with("\e[32mProvide billing details. Opening browser...\e[0m")
      @app.should_receive(:open_billing_page)
      fake_stdin(["staging", "foooo", ""]) do
        @main.add
      end
    end

    it "should display info about adding Cloudfile to repository" do
      $stdout.should_receive(:puts).with("\e[32mProject is now configured for use with Shell Cloud:\e[0m")
      $stdout.should_receive(:puts).with("\e[32mYou can review changes using\e[0m")
      $stdout.should_receive(:puts).with("  git status")
      fake_stdin(["staging", "foooo", "none"]) do
        @main.add
      end
    end

    it "should display info on how to deploy to ShellyCloud" do
      $stdout.should_receive(:puts).with("\e[32mWhen you make sure all settings are correct please issue following commands:\e[0m")
      $stdout.should_receive(:puts).with("  git add .")
      $stdout.should_receive(:puts).with('  git commit -m "Application added to Shelly Cloud"')
      $stdout.should_receive(:puts).with("  git push")
      $stdout.should_receive(:puts).with("\e[32mDeploy to staging using:\e[0m")
      $stdout.should_receive(:puts).with("  git push staging master")
      fake_stdin(["staging", "foooo", "none"]) do
        @main.add
      end
    end
  end
end

