require "spec_helper"
require "shelly/cli/main"

describe Shelly::CLI::Main do
  before do
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
  shelly user <command>    # Manages users using this app
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
      FileUtils.mkdir_p("~/.ssh")
      File.open("~/.ssh/id_rsa.pub", "w") { |f| f << "ssh-key AAbbcc" }
      @client.stub(:ssh_key_available?)
      Shelly::User.stub(:new).and_return(@user)
    end

    it "should return false if ssh key don't exist on local hard drive" do
      FileUtils.rm_rf(@key_path)
      File.exists?(@key_path).should be_false
      $stdout.should_receive(:puts).with("\e[31mNo such file or directory - " + @key_path + "\e[0m")
      $stdout.should_receive(:puts).with("\e[31mUse ssh-keygen to generate ssh key pair\e[0m")
      lambda {
        @main.register
      }.should raise_error(SystemExit)
    end

    it "should check ssh key in database" do
      @user.stub(:ssh_key_registered?).and_raise(RestClient::Conflict)
      $stdout.should_receive(:puts).with("\e[31mUser with your ssh key already exists.\e[0m")
      $stdout.should_receive(:puts).with("\e[31mYou can login using: shelly login [EMAIL]\e[0m")
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
      @client.should_receive(:register_user).with("kate@example.com", "secret", "ssh-key AAbbcc")
      fake_stdin(["", "secret", "secret"]) do
        @main.register
      end
    end

    it "should use email provided by user" do
      @client.should_receive(:register_user).with("better@example.com", "secret", "ssh-key AAbbcc")
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
        $stdout.should_receive(:puts).with("\e[31mEmail can't be blank, please try again\e[0m")
        lambda {
          fake_stdin(["", "bob@example.com", "only-pass", "only-pass"]) do
            @main.register
          end
        }.should raise_error(SystemExit)
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
        @user.stub(:ssh_key_registered?)
        FileUtils.rm_rf(@key_path)
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
        $stdout.should_receive(:puts).with("\e[31mEmail has been already taken\e[0m")
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
        response = {"message" => "Unauthorized", "url" => "https://admin.winniecloud.com/users/password/new"}
        exception = Shelly::Client::APIError.new(response.to_json)
        @client.stub(:token).and_raise(exception)
        $stdout.should_receive(:puts).with("\e[31mWrong email or password\e[0m")
        $stdout.should_receive(:puts).with("\e[31mYou can reset password by using link:\e[0m")
        $stdout.should_receive(:puts).with("\e[31mhttps://admin.winniecloud.com/users/password/new\e[0m")
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
      $stdout.should_receive(:puts).with("\e[31mMust be run inside your project git repository\e[0m")
      lambda {
        fake_stdin(["", ""]) do
          @main.add
        end
      }.should raise_error(SystemExit)
    end

    context "command line options" do

      context "invalid params" do
        it "should show help and exit if not all options are passed" do
          $stdout.should_receive(:puts).with("\e[31mTry 'shelly help add' for more information\e[0m")
          @main.options = {"code-name" => "foo"}
          lambda { @main.add }.should raise_error(SystemExit)
        end

        it "should exit if databases are not valid" do
          $stdout.should_receive(:puts).with("\e[31mTry 'shelly help add' for more information\e[0m")
          @main.options = {"code-name" => "foo", "databases" => ["not existing"], "domains" => ["foo.example.com"]}
          lambda { @main.add }.should raise_error(SystemExit)
        end

        it "should display which parameter was wrong" do
          expected = "shelly: unrecognized option '--unknown=param'\n" +
                      "Usage: shelly [COMMAND]... [OPTIONS]\n" +
                      "Try 'shelly --help' for more information"

          Open3.popen3("bin/shelly add --unknown=param") do |stdin, stdout, stderr, wait_thr|
            out = stderr.read.strip
            out.should == expected
          end
        end

      end

      context "valid params" do
        it "should create app on shelly cloud" do
          @app.should_receive(:create)
          @main.options = {"code-name" => "foo", "databases" => ["postgresql"], "domains" => ["foo.example.com"]}
          @main.add
        end
      end
    end

    it "should use code name provided by user" do
      $stdout.should_receive(:print).with("Application code name (foo-production - default): ")
      @app.should_receive(:code_name=).with("mycodename")
      fake_stdin(["mycodename", ""]) do
        @main.add
      end
    end

    context "when user provided empty code name" do
      it "should use 'current_dirname-purpose' as default" do
        $stdout.should_receive(:print).with("Application code name (foo-production - default): ")
        @app.should_receive(:code_name=).with("foo-production")
        fake_stdin(["", ""]) do
          @main.add
        end
      end
    end

    it "should use database provided by user (separated by comma or space)" do
      $stdout.should_receive(:print).with("Which database do you want to use postgresql, mongodb, redis, none (postgresql - default): ")
      @app.should_receive(:databases=).with(["postgresql", "mongodb", "redis"])
      fake_stdin(["", "postgresql  ,mongodb redis"]) do
        @main.add
      end
    end

    it "should ask again for databases if unsupported kind typed" do
      $stdout.should_receive(:print).with("Which database do you want to use postgresql, mongodb, redis, none (postgresql - default): ")
      $stdout.should_receive(:print).with("Unknown database kind. Supported are: postgresql, mongodb, redis, none: ")
      fake_stdin(["", "postgresql,doesnt-exist", "none"]) do
        @main.add
      end
    end

    context "when user provided empty database" do
      it "should use 'postgresql' database as default" do
        @app.should_receive(:databases=).with(["postgresql"])
        fake_stdin(["", ""]) do
          @main.add
        end
      end
    end

    it "should create the app on shelly cloud" do
      @app.should_receive(:create)
      fake_stdin(["", ""]) do
        @main.add
      end
    end

    it "should display validation errors if they are any" do
      response = {"message" => "Validation Failed", "errors" => [["code_name", "has been already taken"]]}
      exception = Shelly::Client::APIError.new(response.to_json)
      @app.should_receive(:create).and_raise(exception)
      $stdout.should_receive(:puts).with("\e[31mCode name has been already taken\e[0m")
      $stdout.should_receive(:puts).with("\e[31mFix erros in the below command and type it again to create your application\e[0m")
      $stdout.should_receive(:puts).with("\e[31mshelly add --code-name=foo-production --databases=postgresql --domains=foo-production.shellyapp.com\e[0m")
      lambda {
        fake_stdin(["", ""]) do
          @main.add
        end
      }.should raise_error(SystemExit)
    end

    it "should add git remote" do
      $stdout.should_receive(:puts).with("\e[32mAdding remote production git@git.shellycloud.com:foooo.git\e[0m")
      @app.should_receive(:add_git_remote)
      fake_stdin(["foooo", ""]) do
        @main.add
      end
    end

    it "should create Cloudfile" do
      File.exists?("/projects/foo/Cloudfile").should be_false
      fake_stdin(["foooo", ""]) do
        @main.add
      end
      File.read("/projects/foo/Cloudfile").should == "Example Cloudfile"
    end

    it "should browser window with link to edit billing information" do
      $stdout.should_receive(:puts).with("\e[32mProvide billing details. Opening browser...\e[0m")
      @app.should_receive(:open_billing_page)
      fake_stdin(["foooo", ""]) do
        @main.add
      end
    end

    it "should display info about adding Cloudfile to repository" do
      $stdout.should_receive(:puts).with("\e[32mProject is now configured for use with Shell Cloud:\e[0m")
      $stdout.should_receive(:puts).with("\e[32mYou can review changes using\e[0m")
      $stdout.should_receive(:puts).with("  git status")
      fake_stdin(["foooo", "none"]) do
        @main.add
      end
    end

    it "should display info on how to deploy to ShellyCloud" do
      $stdout.should_receive(:puts).with("\e[32mWhen you make sure all settings are correct please issue following commands:\e[0m")
      $stdout.should_receive(:puts).with("  git add .")
      $stdout.should_receive(:puts).with('  git commit -m "Application added to Shelly Cloud"')
      $stdout.should_receive(:puts).with("  git push")
      $stdout.should_receive(:puts).with("\e[32mDeploy to production using:\e[0m")
      $stdout.should_receive(:puts).with("  git push production master")
      fake_stdin(["foooo", "none"]) do
        @main.add
      end
    end
  end
end

