# encoding: utf-8
require "spec_helper"
require "shelly/cli/main"
require "grit"

describe Shelly::CLI::Main do
  before do
    FileUtils.stub(:chmod)
    @main = Shelly::CLI::Main.new
    Shelly::CLI::Main.stub(:new).and_return(@main)
    @client = mock
    @client.stub(:token).and_return("abc")
    Shelly::Client.stub(:new).and_return(@client)
    Shelly::User.stub(:guess_email).and_return("")
    $stdout.stub(:puts)
    $stdout.stub(:print)
  end

  describe "#version" do
    it "should return shelly's version" do
      $stdout.should_receive(:puts).with("shelly version #{Shelly::VERSION}")
      invoke(@main, :version)
    end
  end

  describe "#help" do
    it "should display available commands" do
      out = IO.popen("bin/shelly --debug").read.strip
      out.should include("Tasks:")
      out.should include("shelly add                # Add a new cloud")
      out.should include("shelly backup <command>   # Manage database backups")
      out.should include("shelly check              # Check if application fulfills Shelly Cloud requirements")
      out.should include("shelly config <command>   # Manage application configuration files")
      out.should include("shelly console            # Open application console")
      out.should include("shelly dbconsole          # Run rails dbconsole")
      out.should include("shelly delete             # Delete the cloud")
      out.should include("shelly deploys <command>  # View deploy logs")
      out.should include("shelly files <command>    # Upload and download files to and from persistent storage")
      out.should include("shelly help [TASK]        # Describe available tasks or one specific task")
      out.should include("shelly info               # Show basic information about cloud")
      out.should include("shelly list               # List available clouds")
      out.should include("shelly login [EMAIL]      # Log into Shelly Cloud")
      out.should include("shelly logout             # Logout from Shelly Cloud")
      out.should include("shelly logs               # Show latest application logs")
      out.should include("shelly open               # Open application page in browser")
      out.should include("shelly rake TASK          # Run rake task")
      out.should include("shelly redeploy           # Redeploy application")
      out.should include("shelly register [EMAIL]   # Register new account")
      out.should include("shelly setup              # Set up git remotes for deployment on Shelly Cloud")
      out.should include("shelly start              # Start the cloud")
      out.should include("shelly stop               # Shutdown the cloud")
      out.should include("shelly user <command>     # Manage collaborators")
      out.should include("Options")
      out.should include("[--debug]  # Show debug information")
      out.should include("-h, [--help]   # Describe available tasks or one specific task")
    end

    it "should display options in help for logs" do
      out = IO.popen("bin/shelly help logs").read.strip
      out.should include("-c, [--cloud=CLOUD]    # Specify cloud")
      out.should include("-n, [--limit=N]        # Amount of messages to show")
      out.should include("-s, [--source=SOURCE]  # Limit logs to a single source, e.g. nginx")
      out.should include("-f, [--tail]           # Show new logs automatically")
      out.should include("[--from=FROM]      # Time from which to find the logs")
      out.should include("[--debug]          # Show debug information")
    end

    it "should display help when user is not logged in" do
      out = IO.popen("bin/shelly list --help").read.strip
      out.should include("Usage:")
      out.should include("shelly list")
      out.should include("List available clouds")
      out.should_not include("You are not logged in. To log in use: `shelly login`")
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

    it "should register user without local SSH Key and show message to create SSH Key" do
      FileUtils.rm_rf(@key_path)
      File.exists?(@key_path).should be_false
      $stdout.should_receive(:puts).with(red "No such file or directory - #{@key_path}")
      $stdout.should_receive(:puts).with(red "Use ssh-keygen to generate ssh key pair, after that use: `shelly login`")
      fake_stdin(["better@example.com", "secret", "secret", "yes"]) do
        invoke(@main, :register)
      end
    end

    it "should ask for email, password and password confirmation" do
      $stdout.should_receive(:print).with("Email: ")
      $stdout.should_receive(:print).with("Password: ")
      $stdout.should_receive(:print).with("Password confirmation: ")
      fake_stdin(["better@example.com", "secret", "secret", "yes"]) do
        invoke(@main, :register)
      end
    end

    it "should suggest email and use it if user enters blank email" do
      Shelly::User.stub(:guess_email).and_return("kate@example.com")
      $stdout.should_receive(:print).with("Email (kate@example.com - default): ")
      @client.should_receive(:register_user).with("kate@example.com", "secret", "ssh-key AAbbcc")
      fake_stdin(["", "secret", "secret", "yes"]) do
        invoke(@main, :register)
      end
    end

    it "should use email provided by user" do
      @client.should_receive(:register_user).with("better@example.com", "secret", "ssh-key AAbbcc")
      fake_stdin(["better@example.com", "secret", "secret", "yes"]) do
        invoke(@main, :register)
      end
    end

    it "should not ask about email if it's provided as argument" do
      $stdout.should_receive(:puts).with("Registering with email: kate@example.com")
      fake_stdin(["secret", "secret", "yes"]) do
        invoke(@main, :register, "kate@example.com")
      end
    end

    context "when user enters blank email" do
      it "should show error message and exit with 1" do
        Shelly::User.stub(:guess_email).and_return("")
        $stdout.should_receive(:puts).with("\e[31mEmail can't be blank, please try again\e[0m")
        lambda {
          fake_stdin(["", "bob@example.com", "only-pass", "only-pass", "yes"]) do
            invoke(@main, :register)
          end
        }.should raise_error(SystemExit)
      end
    end

    context "public SSH key exists" do
      it "should register with the public SSH key" do
        FileUtils.mkdir_p("~/.ssh")
        File.open(@key_path, "w") { |f| f << "key" }
        $stdout.should_receive(:puts).with("Uploading your public SSH key from #{@key_path}")
        fake_stdin(["kate@example.com", "secret", "secret", "yes"]) do
          invoke(@main, :register)
        end
      end
    end

    context "public SSH key doesn't exist" do
      it "should register user without the public SSH key" do
        @user.stub(:ssh_key_registered?)
        FileUtils.rm_rf(@key_path)
        $stdout.should_not_receive(:puts).with("Uploading your public SSH key from #{@key_path}")
        fake_stdin(["kate@example.com", "secret", "secret", "yes"]) do
          invoke(@main, :register)
        end
      end
    end

    context "on successful registration" do
      it "should display message about registration and email address confirmation" do
        @client.stub(:register_user).and_return(true)
        $stdout.should_receive(:puts).with(green "Successfully registered!")
        $stdout.should_receive(:puts).with(green "Check you mailbox for email address confirmation")
        fake_stdin(["kate@example.com", "pass", "pass", "yes"]) do
          invoke(@main, :register)
        end
      end
    end

    context "on unsuccessful registration" do
      it "should display errors and exit with 1" do
        body = {"message" => "Validation Failed", "errors" => [["email", "has been already taken"]]}
        exception = Shelly::Client::ValidationException.new(body)
        @client.stub(:register_user).and_raise(exception)
        $stdout.should_receive(:puts).with("\e[31mEmail has been already taken\e[0m")
        lambda {
          fake_stdin(["kate@example.com", "pass", "pass", "yes"]) do
            invoke(@main, :register)
          end
        }.should raise_error(SystemExit)
      end
    end

    context "on rejected Terms of Service" do
      it "should display error and exit with 1" do
        $stdout.should_receive(:puts).with("\e[31mYou must accept the Terms of Service to use Shelly Cloud\e[0m")
        lambda {
          fake_stdin(["kate@example.com", "pass", "pass", "no"]) do
            invoke(@main, :register)
          end
        }.should raise_error(SystemExit)
      end
    end
  end

  describe "#login" do
    before do
      @user = Shelly::User.new
      @key_path = File.expand_path("~/.ssh/id_rsa.pub")
      FileUtils.mkdir_p("~/.ssh")
      File.open("~/.ssh/id_rsa.pub", "w") { |f| f << "ssh-key AAbbcc" }
      @user.stub(:upload_ssh_key)
      @client.stub(:token).and_return("abc")
      @client.stub(:apps).and_return([{"code_name" => "abc", "state" => "running"},
        {"code_name" => "fooo", "state" => "no_code"},])
      Shelly::User.stub(:new).and_return(@user)
    end

    it "should ask about email and password" do
      fake_stdin(["megan@example.com", "secret"]) do
        invoke(@main, :login)
      end
    end

    context "on successful login" do
      it "should display message about successful login" do
        $stdout.should_receive(:puts).with(green "Login successful")
        fake_stdin(["megan@example.com", "secret"]) do
          invoke(@main, :login)
        end
      end

      it "should accept email as parameter" do
        $stdout.should_receive(:puts).with(green "Login successful")
        fake_stdin(["secret"]) do
          invoke(@main, :login, "megan@example.com")
        end
      end

      it "should upload user's public SSH key" do
        @user.should_receive(:upload_ssh_key)
        $stdout.should_receive(:puts).with("Uploading your public SSH key")
        fake_stdin(["megan@example.com", "secret"]) do
          invoke(@main, :login)
        end
      end

      it "should display list of applications to which user has access" do
        $stdout.should_receive(:puts).with("\e[32mYou have following clouds available:\e[0m")
        $stdout.should_receive(:puts).with(/  abc\s+\|  running/)
        $stdout.should_receive(:puts).with(/  fooo\s+\|  no code/)
        fake_stdin(["megan@example.com", "secret"]) do
          invoke(@main, :login)
        end
      end
    end

    context "when local ssh key doesn't exists" do
      it "should display error message and return exit with 1" do
        FileUtils.rm_rf(@key_path)
        File.exists?(@key_path).should be_false
        $stdout.should_receive(:puts).with("\e[31mNo such file or directory - " + @key_path + "\e[0m")
        $stdout.should_receive(:puts).with("\e[31mUse ssh-keygen to generate ssh key pair\e[0m")
        lambda {
          invoke(@main, :login)
        }.should raise_error(SystemExit)
      end
    end

    context "on unauthorized user" do
      it "should exit with 1 and display error message" do
        response = {"message" => "Unauthorized", "url" => "https://admin.winniecloud.com/users/password/new"}
        exception = Shelly::Client::UnauthorizedException.new(response)
        @client.stub(:token).and_raise(exception)
        $stdout.should_receive(:puts).with("\e[31mWrong email or password\e[0m")
        $stdout.should_receive(:puts).with("\e[31mYou can reset password by using link:\e[0m")
        $stdout.should_receive(:puts).with("\e[31mhttps://admin.winniecloud.com/users/password/new\e[0m")
        lambda {
          fake_stdin(["megan@example.com", "secret"]) do
            invoke(@main, :login)
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
      @app.stub(:create_cloudfile)
      @app.stub(:git_url).and_return("git@git.shellycloud.com:foooo.git")
      Shelly::App.stub(:inside_git_repository?).and_return(true)
      Shelly::App.stub(:new).and_return(@app)
      @client.stub(:token).and_return("abc")
      @app.stub(:attributes).and_return({"trial" => false})
      @app.stub(:git_remote_exist?).and_return(false)
      @main.stub(:check => true)
    end

    # This spec tests inside_git_repository? hook
    it "should exit with message if command run outside git repository" do
      Shelly::App.stub(:inside_git_repository?).and_return(false)
      $stdout.should_receive(:puts).with("\e[31mMust be run inside your project git repository\e[0m")
      lambda {
        fake_stdin(["", ""]) do
          invoke(@main, :add)
        end
      }.should raise_error(SystemExit)
    end

    # This spec tests logged_in? hook
    it "should exit with message if user is not logged in" do
      exception = Shelly::Client::UnauthorizedException.new
      @client.stub(:token).and_raise(exception)
      $stdout.should_receive(:puts).with(red "You are not logged in. To log in use: `shelly login`")
      lambda {
        fake_stdin(["", ""]) do
          invoke(@main, :add)
        end
      }.should raise_error(SystemExit)
    end

    context "command line options" do
      context "invalid params" do
        it "should exit if databases are not valid" do
          $stdout.should_receive(:puts).with("\e[31mTry `shelly help add` for more information\e[0m")
          @main.options = {"code-name" => "foo", "databases" => ["not existing"]}
          lambda {
            invoke(@main, :add)
          }.should raise_error(SystemExit)
        end

        it "should exit if size is not valid" do
          $stdout.should_receive(:puts).with("\e[31mTry `shelly help add` for more information\e[0m")
          @main.options = {"size" => "wrong_size"}
          lambda {
            invoke(@main, :add)
          }.should raise_error(SystemExit)
        end
      end

      context "valid params" do
        it "should create app on shelly cloud" do
          @app.should_receive(:create)
          @main.options = {"code-name" => "foo", "databases" => ["postgresql"], "size" => "large"}
          invoke(@main, :add)
        end
      end
    end

    it "should use code name provided by user" do
      $stdout.should_receive(:print).with("Cloud code name (foo-staging - default): ")
      @app.should_receive(:code_name=).with("mycodename")
      fake_stdin(["mycodename", ""]) do
        invoke(@main, :add)
      end
    end

    context "when user provided empty code name" do
      it "should use 'current_dirname-purpose' as default" do
        $stdout.should_receive(:print).with("Cloud code name (foo-staging - default): ")
        @app.should_receive(:code_name=).with("foo-staging")
        fake_stdin(["", ""]) do
          invoke(@main, :add)
        end
      end
    end

    it "should use database provided by user (separated by comma or space)" do
      $stdout.should_receive(:print).with("Which database do you want to use postgresql, mongodb, redis, none (postgresql - default): ")
      @app.should_receive(:databases=).with(["postgresql", "mongodb", "redis"])
      fake_stdin(["", "postgresql  ,mongodb redis"]) do
        invoke(@main, :add)
      end
    end

    it "should ask again for databases if unsupported kind typed" do
      $stdout.should_receive(:print).with("Which database do you want to use postgresql, mongodb, redis, none (postgresql - default): ")
      $stdout.should_receive(:print).with("Unknown database kind. Supported are: postgresql, mongodb, redis, none: ")
      fake_stdin(["", "postgresql,doesnt-exist", "none"]) do
        invoke(@main, :add)
      end
    end

    context "when user provided empty database" do
      it "should use 'postgresql' database as default" do
        @app.should_receive(:databases=).with(["postgresql"])
        fake_stdin(["", ""]) do
          invoke(@main, :add)
        end
      end
    end

    context "when user provided 'none' database" do
      it "shouldn't take it into account" do
        fake_stdin(["", "postgresql, none"]) do
          invoke(@main, :add)
        end
        @app.databases.should == ['postgresql']
      end
    end

    it "should create the app on shelly cloud" do
      @app.should_receive(:create)
      fake_stdin(["", ""]) do
        invoke(@main, :add)
      end
    end

    it "should create the app on shelly cloud and show trial information" do
      @app.stub(:attributes).and_return({"trial" => true, "credit" => 40})
      @client.stub(:shellyapp_url).and_return("http://example.com")
      @app.should_receive(:create)
      $stdout.should_receive(:puts).with(green "Billing information")
      $stdout.should_receive(:puts).with("Cloud created with 40 Euro credit.")
      $stdout.should_receive(:puts).with("Remember to provide billing details before trial ends.")
      $stdout.should_receive(:puts).with("http://example.com/apps/foo-staging/billing/edit")

      fake_stdin(["", ""]) do
        invoke(@main, :add)
      end
    end

    it "should create the app on shelly cloud and shouldn't show trial information" do
      @app.should_receive(:create)
      $stdout.should_not_receive(:puts).with(green "Billing information")

      fake_stdin(["", ""]) do
        invoke(@main, :add)
      end
    end

    it "should display validation errors if they are any" do
      body = {"message" => "Validation Failed", "errors" => [["code_name", "has been already taken"]]}
      exception = Shelly::Client::ValidationException.new(body)
      @app.should_receive(:create).and_raise(exception)
      $stdout.should_receive(:puts).with(red "Code name has been already taken")
      $stdout.should_receive(:puts).with(red "Fix erros in the below command and type it again to create your cloud")
      $stdout.should_receive(:puts).with(red "shelly add --code-name=big-letters --databases=postgresql --size=large")
      lambda {
        fake_stdin(["BiG_LETTERS", ""]) do
          invoke(@main, :add)
        end
      }.should raise_error(SystemExit)
    end

    context "git remote" do
      it "should add one if it doesn't exist" do
        $stdout.should_receive(:puts).with("\e[32mAdding remote foooo git@git.shellycloud.com:foooo.git\e[0m")
        @app.should_receive(:add_git_remote)
        fake_stdin(["foooo", ""]) do
          invoke(@main, :add)
        end
      end

      context "does exist" do
        before do
          @app.stub(:git_remote_exist?).and_return(true)
        end

        it "should ask if one exist and overwrite" do
          $stdout.should_receive(:print).with("Git remote foooo exists, overwrite (yes/no):  ")
          $stdout.should_receive(:puts).with(green "Adding remote foooo git@git.shellycloud.com:foooo.git")
          @app.should_receive(:add_git_remote)
          fake_stdin(["foooo", "", "yes"]) do
            invoke(@main, :add)
          end
        end

        it "should ask if one exist and not overwrite" do
          $stdout.should_receive(:print).with("Git remote foooo exists, overwrite (yes/no):  ")
          $stdout.should_receive(:puts).with("You have to manually add git remote:")
          $stdout.should_receive(:puts).with("`git remote add NAME git@git.shellycloud.com:foooo.git`")
          @app.should_not_receive(:add_git_remote)
          fake_stdin(["foooo", "", "no"]) do
            invoke(@main, :add)
          end
        end
      end
    end

    it "should create Cloudfile" do
      @app.should_receive(:create_cloudfile)
      fake_stdin(["foooo", ""]) { invoke(@main, :add) }
    end

    it "should display info about adding Cloudfile to repository" do
      $stdout.should_receive(:puts).with("\e[32mProject is now configured for use with Shell Cloud:\e[0m")
      $stdout.should_receive(:puts).with("\e[32mYou can review changes using\e[0m")
      $stdout.should_receive(:puts).with("  git status")
      fake_stdin(["foooo", "none"]) do
        invoke(@main, :add)
      end
    end

    it "should display info on how to deploy to ShellyCloud" do
      $stdout.should_receive(:puts).with("\e[32mWhen you make sure all settings are correct please issue following commands:\e[0m")
      $stdout.should_receive(:puts).with("  git add .")
      $stdout.should_receive(:puts).with('  git commit -m "Application added to Shelly Cloud"')
      $stdout.should_receive(:puts).with("  git push")
      $stdout.should_receive(:puts).with("\e[32mDeploy to your cloud using:\e[0m")
      $stdout.should_receive(:puts).with("  git push foooo master")
      fake_stdin(["foooo", "none"]) do
        invoke(@main, :add)
      end
    end

    it "should check shelly requirements" do
      $stdout.should_receive(:puts) \
        .with("\e[32mWhen you make sure all settings are correct please issue following commands:\e[0m")
      @main.should_receive(:check).with(false).and_return(true)
      fake_stdin(["foooo", "none"]) do
        invoke(@main, :add)
      end
    end

    it "should abort when shelly requirements are not met" do
      $stdout.should_not_receive(:puts) \
        .with("\e[32mWhen you make sure all settings are correct please issue following commands:\e[0m")
      @main.should_receive(:check).with(false).and_return(false)
      fake_stdin(["foooo", "none"]) do
        invoke(@main, :add)
      end
    end
  end

  describe "#list" do
    before do
      @user = Shelly::User.new
      @client.stub(:token).and_return("abc")
      @client.stub(:apps).and_return([
        {"code_name" => "abc", "state" => "running"},
        {"code_name" => "fooo", "state" => "deploy_failed"},
        {"code_name" => "bar", "state" => "configuration_failed"}
      ])
      Shelly::User.stub(:new).and_return(@user)
    end

    it "should ensure user has logged in" do
      hooks(@main, :list).should include(:logged_in?)
    end

    it "should display user's clouds" do
      $stdout.should_receive(:puts).with("\e[32mYou have following clouds available:\e[0m")
      $stdout.should_receive(:puts).with(/abc\s+\|  running/)
      $stdout.should_receive(:puts).with(/fooo\s+\|  deploy failed \(deployment log: `shelly deploys show last -c fooo`\)/)
      $stdout.should_receive(:puts).with(/bar\s+\|  configuration failed \(deployment log: `shelly deploys show last -c bar`\)/)
      invoke(@main, :list)
    end

    it "should display info that user has no clouds" do
      @client.stub(:apps).and_return([])
      $stdout.should_receive(:puts).with("\e[32mYou have no clouds yet\e[0m")
      invoke(@main, :list)
    end

    context "#status" do
      it "should ensure user has logged in" do
        hooks(@main, :status).should include(:logged_in?)
      end

      it "should have a 'status' alias" do
        @client.stub(:apps).and_return([])
        $stdout.should_receive(:puts).with("\e[32mYou have no clouds yet\e[0m")
        invoke(@main, :status)
      end
    end
  end

  describe "#start" do
    before do
      setup_project
      @client.stub(:apps).and_return([
        {"code_name" => "foo-production", "state" => "running"},
        {"code_name" => "foo-staging", "state" => "no_code"}])
    end

    it "should ensure user has logged in" do
      hooks(@main, :start).should include(:logged_in?)
    end

    context "single cloud in Cloudfile" do
      it "should start the cloud" do
        @client.stub(:start_cloud)
        $stdout.should_receive(:puts).with(green "Starting cloud foo-production.")
        $stdout.should_receive(:puts).with("This can take up to 10 minutes.")
        $stdout.should_receive(:puts).with("Check status with: `shelly list`")
        invoke(@main, :start)
      end
    end

    # this tests multiple_clouds method used in majority of tasks
    context "without Cloudfile" do
      it "should use cloud from params" do
        Dir.chdir("/projects")
        @client.stub(:start_cloud)
        $stdout.should_receive(:puts).with(green "Starting cloud foo-production.")
        @main.options = {:cloud => "foo-production"}
        invoke(@main, :start)
      end

      it "should ask user to specify cloud, list all clouds and exit" do
        Dir.chdir("/projects")
        @client.stub(:start_cloud)
        $stdout.should_receive(:puts).with(red "You have to specify cloud.")
        $stdout.should_receive(:puts).with("Select cloud using `shelly start --cloud CLOUD_NAME`")
        $stdout.should_receive(:puts).with(green "You have following clouds available:")
        $stdout.should_receive(:puts).with("  foo-production  |  running")
        $stdout.should_receive(:puts).with("  foo-staging     |  no code")
        lambda { invoke(@main, :start) }.should raise_error(SystemExit)
      end
    end

    # this tests multiple_clouds method used in majority of tasks
    context "multiple clouds in Cloudfile" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show information to start specific cloud and exit" do
        $stdout.should_receive(:puts).with(red "You have multiple clouds in Cloudfile.")
        $stdout.should_receive(:puts).with("Select cloud using `shelly start --cloud foo-production`")
        $stdout.should_receive(:puts).with("Available clouds:")
        $stdout.should_receive(:puts).with(" * foo-production")
        $stdout.should_receive(:puts).with(" * foo-staging")
        lambda { invoke(@main, :start) }.should raise_error(SystemExit)
      end

      it "should fetch from command line which cloud to start" do
        @client.should_receive(:start_cloud).with("foo-staging")
        $stdout.should_receive(:puts).with(green "Starting cloud foo-staging.")
        $stdout.should_receive(:puts).with("Check status with: `shelly list`")
        @main.options = {:cloud => "foo-staging"}
        invoke(@main, :start)
      end
    end

    context "on failure" do
      it "should show information that cloud is running" do
        raise_conflict("state" => "running")
        $stdout.should_receive(:puts).with(red "Not starting: cloud 'foo-production' is already running")
        lambda { invoke(@main, :start)  }.should raise_error(SystemExit)
      end

      %w{deploying configuring}.each do |state|
        it "should show information that cloud is #{state}" do
          raise_conflict("state" => state)
          $stdout.should_receive(:puts).with(red "Not starting: cloud 'foo-production' is currently deploying")
          lambda { invoke(@main, :start) }.should raise_error(SystemExit)
        end
      end

      it "should show information that cloud has no code" do
        raise_conflict("state" => "no_code")
        $stdout.should_receive(:puts).with(red "Not starting: no source code provided")
        $stdout.should_receive(:puts).with(red "Push source code using:")
        $stdout.should_receive(:puts).with("`git push foo-production master`")
        lambda { invoke(@main, :start) }.should raise_error(SystemExit)
      end

      %w{deploy_failed configuration_failed}.each do |state|
        it "should show information that cloud #{state}" do
          raise_conflict("state" => state)
          $stdout.should_receive(:puts).with(red "Not starting: deployment failed")
          $stdout.should_receive(:puts).with(red "Support has been notified")
          $stdout.should_receive(:puts).
            with(red "Check `shelly deploys show last --cloud foo-production` for reasons of failure")
          lambda { invoke(@main, :start) }.should raise_error(SystemExit)
        end
      end

      it "should show that winnie is out of resources" do
        raise_conflict("state" => "not_enough_resources")
        $stdout.should_receive(:puts).with(red "Sorry, There are no resources for your servers.
We have been notified about it. We will be adding new resources shortly")
        lambda { invoke(@main, :start) }.should raise_error(SystemExit)
      end

      it "should show messages about billing" do
        raise_conflict("state" => "no_billing")
        @app.stub(:edit_billing_url).and_return("http://example.com/billing/edit")
        $stdout.should_receive(:puts).with(red "Please fill in billing details to start foo-production.")
        $stdout.should_receive(:puts).with(red "Visit: http://example.com/billing/edit")
        @client.stub(:shellyapp_url).and_return("http://example.com")
        lambda { invoke(@main, :start) }.should raise_error(SystemExit)
      end

      it "should show messge about payment declined" do
        raise_conflict("state" => "payment_declined")
        $stdout.should_receive(:puts).with(red "Not starting. Invoice for cloud 'foo-production' was declined.")
        lambda { invoke(@main, :start) }.should raise_error(SystemExit)
      end

      def raise_conflict(options = {})
        body = {"state" => "no_code"}.merge(options)
        exception = Shelly::Client::ConflictException.new(body)
        @client.stub(:start_cloud).and_raise(exception)
      end
    end
  end

  describe "#stop" do
    before do
      @user = Shelly::User.new
      @client.stub(:token).and_return("abc")
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-production:\n") }
      Shelly::User.stub(:new).and_return(@user)
      @client.stub(:apps).and_return([{"code_name" => "foo-production"}, {"code_name" => "foo-staging"}])
      @app = Shelly::App.new
      Shelly::App.stub(:new).and_return(@app)
    end

    it "should ensure user has logged in" do
      hooks(@main, :stop).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.stub(:stop_cloud)
      @main.should_receive(:multiple_clouds).and_return(@app)
      fake_stdin(["yes"]) do
        invoke(@main, :stop)
      end
    end

    it "should exit if user doesn't have access to clouds in Cloudfile" do
      @client.stub(:stop_cloud).and_raise(Shelly::Client::NotFoundException.new("resource" => "cloud"))
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
      lambda {
        fake_stdin(["yes"]) do
          invoke(@main, :stop)
        end
      }.should raise_error(SystemExit)
    end

    it "should stop the cloud" do
      @client.stub(:stop_cloud)
      $stdout.should_receive(:print).with("Are you sure you want to shut down your application (yes/no): ")
      $stdout.should_receive(:puts).with("\n")
      $stdout.should_receive(:puts).with("Cloud 'foo-production' stopped")
      fake_stdin(["yes"]) do
        invoke(@main, :stop)
      end
    end

  end

  describe "#info" do
    before do
      File.open("Cloudfile", 'w') { |f| f.write("foo-production:\n") }
      @app = Shelly::App.new("foo-production")
      @main.stub(:logged_in?).and_return(true)
      @app.stub(:attributes).and_return(response)
      @statistics = [{"name" => "app1",
                      "memory" => {"kilobyte" => "276756", "percent" => "74.1"},
                      "swap" => {"kilobyte" => "44332", "percent" => "2.8"},
                      "cpu" => {"wait" => "0.8", "system" => "0.0", "user" => "0.1"},
                      "load" => {"avg15" => "0.13", "avg05" => "0.15", "avg01" => "0.04"}}]
      @app.stub(:statistics).and_return(@statistics)
    end

    it "should ensure user has logged in" do
      hooks(@main, :info).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @main.should_receive(:multiple_clouds).and_return(@app)
      invoke(@main, :info)
    end

    context "on success" do
      it "should display basic information about cloud" do
        @main.should_receive(:multiple_clouds).and_return(@app)
        $stdout.should_receive(:puts).with(green "Cloud foo-production:")
        $stdout.should_receive(:puts).with("  State: running")
        $stdout.should_receive(:puts).with("  Deployed commit sha: 52e65ed2d085eaae560cdb81b2b56a7d76")
        $stdout.should_receive(:puts).with("  Deployed commit message: Commit message")
        $stdout.should_receive(:puts).with("  Deployed by: megan@example.com")
        $stdout.should_receive(:puts).with("  Repository URL: git@winniecloud.net:example-cloud")
        $stdout.should_receive(:puts).with("  Web server IP: 22.22.22.22")
        $stdout.should_receive(:puts).with("  Statistics:")
        $stdout.should_receive(:puts).with("    app1:")
        $stdout.should_receive(:puts).with("      Load average: 1m: 0.04, 5m: 0.15, 15m: 0.13")
        $stdout.should_receive(:puts).with("      CPU: 0.8%, MEM: 74.1%, SWAP: 2.8%")
        invoke(@main, :info)
      end

      context "when deploy failed or configuration failed" do
        it "should display basic information about information and command to last log" do
          @app.stub(:attributes).and_return(response({"state" => "deploy_failed"}))
          @main.should_receive(:multiple_clouds).and_return(@app)
          $stdout.should_receive(:puts).with(red "Cloud foo-production:")
          $stdout.should_receive(:puts).with("  State: deploy_failed (deployment log: `shelly deploys show last -c foo-production`)")
          $stdout.should_receive(:puts).with("  Deployed commit sha: 52e65ed2d085eaae560cdb81b2b56a7d76")
          $stdout.should_receive(:puts).with("  Deployed commit message: Commit message")
          $stdout.should_receive(:puts).with("  Deployed by: megan@example.com")
          $stdout.should_receive(:puts).with("  Repository URL: git@winniecloud.net:example-cloud")
          $stdout.should_receive(:puts).with("  Web server IP: 22.22.22.22")
          $stdout.should_receive(:puts).with("  Statistics:")
          $stdout.should_receive(:puts).with("    app1:")
          $stdout.should_receive(:puts).with("      Load average: 1m: 0.04, 5m: 0.15, 15m: 0.13")
          $stdout.should_receive(:puts).with("      CPU: 0.8%, MEM: 74.1%, SWAP: 2.8%")
          invoke(@main, :info)
        end

        it "should display basic information about information and command to last log" do
          @app.stub(:attributes).and_return(response({"state" => "configuration_failed"}))
          @main.should_receive(:multiple_clouds).and_return(@app)
          $stdout.should_receive(:puts).with(red "Cloud foo-production:")
          $stdout.should_receive(:puts).with("  State: configuration_failed (deployment log: `shelly deploys show last -c foo-production`)")
          $stdout.should_receive(:puts).with("  Deployed commit sha: 52e65ed2d085eaae560cdb81b2b56a7d76")
          $stdout.should_receive(:puts).with("  Deployed commit message: Commit message")
          $stdout.should_receive(:puts).with("  Deployed by: megan@example.com")
          $stdout.should_receive(:puts).with("  Repository URL: git@winniecloud.net:example-cloud")
          $stdout.should_receive(:puts).with("  Web server IP: 22.22.22.22")
          $stdout.should_receive(:puts).with("  Statistics:")
          $stdout.should_receive(:puts).with("    app1:")
          $stdout.should_receive(:puts).with("      Load average: 1m: 0.04, 5m: 0.15, 15m: 0.13")
          $stdout.should_receive(:puts).with("      CPU: 0.8%, MEM: 74.1%, SWAP: 2.8%")
          invoke(@main, :info)
        end

        it "should not display statistics when statistics are empty" do
          @app.stub(:attributes).and_return(response({"state" => "turned_off"}))
          @main.should_receive(:multiple_clouds).and_return(@app)
          @app.stub(:statistics).and_return([])
          $stdout.should_not_receive(:puts).with("Statistics:")
          invoke(@main, :info)
        end
      end

      context "on failure" do
        it "should raise an error if statistics unavailable" do
          @main.should_receive(:multiple_clouds).and_return(@app)
          exception = Shelly::Client::GatewayTimeoutException.new
          @app.stub(:statistics).and_raise(exception)
          $stdout.should_receive(:puts).with(red "Server statistics temporarily unavailable")
          lambda { invoke(@main, :info) }.should raise_error(SystemExit)
        end
      end
    end

    def response(options = {})
      { "code_name" => "foo-production",
        "state" => "running",
        "git_info" =>
        {
          "deployed_commit_message" => "Commit message",
          "deployed_commit_sha" => "52e65ed2d085eaae560cdb81b2b56a7d76",
          "repository_url" => "git@winniecloud.net:example-cloud",
          "deployed_push_author" => "megan@example.com"
        },
        "web_server_ip" => "22.22.22.22"}.merge(options)
    end
  end

  describe "#setup" do
    before do
      Shelly::App.stub(:inside_git_repository?).and_return(true)
      @client.stub(:token).and_return("abc")
      @client.stub(:app).and_return("git_info" => {"repository_url" => "git_url"})
      @app = Shelly::App.new("foo-staging")
      @app.stub(:git_remote_exist?).and_return(false)
      @app.stub(:system)
      Shelly::App.stub(:new).and_return(@app)
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
    end

    it "should ensure user has logged in" do
      hooks(@main, :setup).should include(:logged_in?)
    end

    it "should ensure that user is inside git repo" do
      hooks(@main, :setup).should include(:inside_git_repository?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @main.should_receive(:multiple_clouds).and_return(@app)
      invoke(@main, :setup)
    end

    it "should show info about adding remote and branch" do
      $stdout.should_receive(:puts).with(green "Setting up foo-staging cloud")
      $stdout.should_receive(:puts).with("git remote add foo-staging git_url")
      $stdout.should_receive(:puts).with("git fetch foo-staging")
      $stdout.should_receive(:puts).with("git checkout -b foo-staging --track foo-staging/master")
      $stdout.should_receive(:puts).with(green "Your application is set up.")
      invoke(@main, :setup)
    end

    it "should add git remote" do
      @app.should_receive(:add_git_remote)
      invoke(@main, :setup)
    end

    it "should fetch remote" do
      @app.should_receive(:git_fetch_remote)
      invoke(@main, :setup)
    end

    it "should add tracking branch" do
      @app.should_receive(:git_add_tracking_branch)
      invoke(@main, :setup)
    end

    context "when remote exists" do
      before do
        @app.stub(:git_remote_exist?).and_return(true)
      end

      context "and user answers yes" do
        it "should overwrite remote" do
          @app.should_receive(:add_git_remote)
          @app.should_receive(:git_fetch_remote)
          @app.should_receive(:git_add_tracking_branch)
          fake_stdin(["yes"]) do
            invoke(@main, :setup)
          end
        end
      end

      context "and user answers no" do
        it "should display commands to perform manually" do
          @app.should_not_receive(:add_git_remote)
          @app.should_not_receive(:git_fetch_remote)
          @app.should_not_receive(:git_add_tracking_branch)
          fake_stdin(["no"]) do
            invoke(@main, :setup)
          end
        end
      end

    end
  end

  describe "#delete" do
    before  do
      Shelly::App.stub(:inside_git_repository?).and_return(true)
      @user = Shelly::User.new
      @app = Shelly::App.new
      @client.stub(:token).and_return("abc")
      @app.stub(:delete)
      Shelly::User.stub(:new).and_return(@user)
      Shelly::App.stub(:new).and_return(@app)
    end

    it "should ensure user has logged in" do
      hooks(@main, :delete).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.stub(:delete)
      @main.should_receive(:multiple_clouds).and_return(@app)
      fake_stdin(["yes", "yes", "yes"]) do
        invoke(@main, :delete)
      end
    end

    context "when cloud is given" do
      before do
        File.open("Cloudfile", 'w') {|f|
          f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should ask about delete application parts" do
        $stdout.should_receive(:puts).with("You are about to delete application: foo-staging.")
        $stdout.should_receive(:puts).with("Press Control-C at any moment to cancel.")
        $stdout.should_receive(:puts).with("Please confirm each question by typing yes and pressing Enter.")
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:print).with("I want to delete all files stored on Shelly Cloud (yes/no): ")
        $stdout.should_receive(:print).with("I want to delete all database data stored on Shelly Cloud (yes/no): ")
        $stdout.should_receive(:print).with("I want to delete the application (yes/no): ")
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:puts).with("Scheduling application delete - done")
        $stdout.should_receive(:puts).with("Removing git remote - done")
        @main.options = {:cloud => "foo-staging"}
        fake_stdin(["yes", "yes", "yes"]) do
          invoke(@main, :delete)
        end
      end

      it "should return exit 1 when user doesn't type 'yes'" do
        @app.should_not_receive(:delete)
        lambda{
          fake_stdin(["yes", "yes", "no"]) do
            @main.options = {:cloud => "foo-staging"}
            invoke(@main, :delete)
          end
        }.should raise_error(SystemExit)
      end
    end

    context "when git repository doesn't exist" do
      before do
        File.open("Cloudfile", 'w') {|f|
          f.write("foo-staging:\n") }
      end

      it "should say that Git remote missing" do
        Shelly::App.stub(:inside_git_repository?).and_return(false)
        $stdout.should_receive(:puts).with("Missing git remote")
        fake_stdin(["yes", "yes", "yes"]) do
          @main.options = {:cloud => "foo-staging"}
          invoke(@main, :delete)
        end
      end
    end

    context "when no cloud option is given" do
      before do
        File.open("Cloudfile", 'w') {|f|
          f.write("foo-staging:\n") }
      end

      it "should take the cloud from Cloudfile" do
        $stdout.should_receive(:puts).with("You are about to delete application: foo-staging.")
        $stdout.should_receive(:puts).with("Press Control-C at any moment to cancel.")
        $stdout.should_receive(:puts).with("Please confirm each question by typing yes and pressing Enter.")
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:print).with("I want to delete all files stored on Shelly Cloud (yes/no): ")
        $stdout.should_receive(:print).with("I want to delete all database data stored on Shelly Cloud (yes/no): ")
        $stdout.should_receive(:print).with("I want to delete the application (yes/no): ")
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:puts).with("Scheduling application delete - done")
        $stdout.should_receive(:puts).with("Removing git remote - done")
        fake_stdin(["yes", "yes", "yes"]) do
          invoke(@main, :delete)
        end
      end
    end
  end

  describe "#logout" do
    before do
      @user = Shelly::User.new
      @client.stub(:token).and_return("abc")
      Shelly::User.stub(:new).and_return(@user)
      FileUtils.mkdir_p("~/.ssh")
      FileUtils.mkdir_p("~/.shelly")
      File.open("Cloudfile", 'w') { |f| f.write("foo-production:\n") }
      File.open("~/.ssh/id_rsa.pub", "w") { |f| f << "ssh-key AAbbcc" }
      @key_path = File.expand_path("~/.ssh/id_rsa.pub")
      File.open("~/.shelly/credentials", "w") { |f| f << "megan@fox.pl\nsecret" }
      @client.stub(:logout).and_return(true)
    end

    it "should ensure user has logged in" do
      hooks(@main, :logout).should include(:logged_in?)
    end

    it "should logout from shelly cloud and show message" do
      $stdout.should_receive(:puts).with("Your public SSH key has been removed from Shelly Cloud")
      $stdout.should_receive(:puts).with("You have been successfully logged out")
      invoke(@main, :logout)
      File.exists?("~/.shelly/credentials").should be_false
    end

    it "should remove only credentiales when local ssh key doesn't exist" do
      FileUtils.rm_rf(@key_path)
      $stdout.should_receive(:puts).with("You have been successfully logged out")
      invoke(@main, :logout)
      File.exists?("~/.shelly/credentials").should be_false
    end
  end

  describe "#logs" do
    before do
      setup_project
      @sample_logs = {"entries" => [['app1', 'log1'], ['app1', 'log2']]}
    end

    it "should ensure user has logged in" do
      hooks(@main, :logs).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.stub(:application_logs).and_return(@sample_logs)
      @main.should_receive(:multiple_clouds).and_return(@app)
      invoke(@main, :logs)
    end

    it "should exit if user requested too many log lines" do
      exception = Shelly::Client::APIException.new({}, 416)
      @client.stub(:application_logs).and_raise(exception)
      $stdout.should_receive(:puts).
        with(red "You have requested too many log messages. Try a lower number.")
      lambda { invoke(@main, :logs) }.should raise_error(SystemExit)
    end

    it "should show logs for the cloud" do
      @client.stub(:application_logs).and_return(@sample_logs)
      $stdout.should_receive(:puts).with("    app1 | log1\n")
      $stdout.should_receive(:puts).with("    app1 | log2\n")
      invoke(@main, :logs)
    end

    it "should show requested amount of logs" do
      @client.should_receive(:application_logs).
        with("foo-production", {:limit => 2, :source => 'nginx'}).and_return(@sample_logs)
      @main.options = {:limit => 2, :source => 'nginx'}
      invoke(@main, :logs)
    end
  end

  describe "#rake" do
    before do
      setup_project
      @main.stub(:rake_args).and_return(%w(db:migrate))
    end

    it "should ensure user has logged in" do
      hooks(@main, :rake).should include(:logged_in?)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @app.stub(:rake)
      @main.should_receive(:multiple_clouds).and_return(@app)
      invoke(@main, :rake, "db:migrate")
    end

    it "should invoke rake task" do
      @app.should_receive(:rake).with("db:migrate")
      invoke(@main, :rake, "db:migrate")
    end

    describe "#rake_args" do
      before { @main.unstub!(:rake_args) }

      it "should return Array of rake arguments (skipping shelly gem arguments)" do
        argv = %w(rake -T db --cloud foo-production --debug)
        @main.rake_args(argv).should == %w(-T db)
      end

      it "should take ARGV as default default argument" do
        # Rather poor, I test if method without args returns the same as method with ARGV
        @main.rake_args.should == @main.rake_args(ARGV)
      end
    end
  end

  describe "#redeploy" do
    before do
      setup_project
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.stub(:redeploy)
      @main.should_receive(:multiple_clouds).and_return(@app)
      invoke(@main, :redeploy)
    end

    it "should redeploy the application" do
      $stdout.should_receive(:puts).with(green "Redeploying your application for cloud 'foo-production'")
      @app.should_receive(:redeploy)
      invoke(@main, :redeploy)
    end

    context "on redeploy failure" do
      %w(deploying configuring).each do |state|
        context "when application is in #{state} state" do
          it "should display error that deploy is in progress" do
            exception = Shelly::Client::ConflictException.new("state" => state)
            @client.should_receive(:redeploy).with("foo-production").and_raise(exception)
            $stdout.should_receive(:puts).with(red "Your application is being redeployed at the moment")
            lambda {
              invoke(@main, :redeploy)
            }.should raise_error(SystemExit)
          end
        end
      end

      %w(no_code no_billing turned_off).each do |state|
        context "when application is in #{state} state" do
          it "should display error that cloud is not running" do
            exception = Shelly::Client::ConflictException.new("state" => state)
            @client.should_receive(:redeploy).with("foo-production").and_raise(exception)
            $stdout.should_receive(:puts).with(red "Cloud foo-production is not running")
            $stdout.should_receive(:puts).with("Start your cloud with `shelly start --cloud foo-production`")
            lambda {
              invoke(@main, :redeploy)
            }.should raise_error(SystemExit)
          end
        end
      end

      it "should re-raise exception on unknown state" do
        exception = Shelly::Client::ConflictException.new("state" => "doing_something")
        @client.should_receive(:redeploy).with("foo-production").and_raise(exception)
        lambda {
          invoke(@main, :redeploy)
        }.should raise_error(Shelly::Client::ConflictException)
      end
    end
  end

  describe "#open" do
    before do
      setup_project
      @app.stub(:open)
    end

    # multiple_clouds is tested in main_spec.rb in describe "#start" block
    it "should ensure multiple_clouds check" do
      @client.stub(:open)
      @main.should_receive(:multiple_clouds).and_return(@app)
      invoke(@main, :open)
    end

    it "should open app" do
      @app.should_receive(:open)
      invoke(@main, :open)
    end
  end

  describe "#console" do
    before do
      setup_project
    end

    it "should ensure user has logged in" do
      hooks(@main, :console).should include(:logged_in?)
    end

    it "execute ssh command" do
      @app.should_receive(:console)
      invoke(@main, :console)
    end

    context "Instances are not running" do
      it "should display error" do
        @client.stub(:console).and_raise(Shelly::Client::ConflictException)
        $stdout.should_receive(:puts).with(red "Cloud foo-production is not running. Cannot run console.")
        lambda {
          invoke(@main, :console)
        }.should raise_error(SystemExit)
      end
    end
  end

  describe "#dbconsole" do
    before do
      setup_project
    end

    it "should ensure user has logged in" do
      hooks(@main, :dbconsole).should include(:logged_in?)
    end

    it "should execute ssh command" do
      @app.should_receive(:dbconsole)
      invoke(@main, :dbconsole)
    end

    context "Instances are not running" do
      it "should display error" do
        @client.stub(:console).and_raise(Shelly::Client::ConflictException)
        $stdout.should_receive(:puts).with(red "Cloud foo-production is not running. Cannot run dbconsole.")
        lambda {
          invoke(@main, :dbconsole)
        }.should raise_error(SystemExit)
      end
    end
  end

  describe "#check" do
    before do
      Shelly::App.stub(:inside_git_repository?).and_return(true)
      Bundler::Definition.stub_chain(:build, :specs, :map) \
        .and_return(["thin"])
      Shelly::StructureValidator.any_instance.stub(:repo_paths) \
        .and_return(["config.ru", "Gemfile", "Gemfile.lock"])
    end

    it "should ensure user is in git repository" do
      hooks(@main, :check).should include(:inside_git_repository?)
    end

    context "when gemfile exists" do
      it "should show that Gemfile exists" do
        $stdout.should_receive(:puts).with("  #{green("✓")} Gemfile is present")
        invoke(@main, :check)
      end
    end

    context "when gemfile doesn't exist" do
      it "should show that Gemfile doesn't exist" do
        Shelly::StructureValidator.any_instance.stub(:repo_paths).and_return([])
        $stdout.should_receive(:puts).with("  #{red("✗")} Gemfile is missing in git repository")
        invoke(@main, :check)
      end
    end

    context "when gemfile exists" do
      it "should show that Gemfile exists" do
        $stdout.should_receive(:puts).with("  #{green("✓")} Gemfile is present")
        invoke(@main, :check)
      end
    end

    context "when gemfile doesn't exist" do
      it "should show that Gemfile doesn't exist" do
        Shelly::StructureValidator.any_instance.stub(:repo_paths).and_return([])
        $stdout.should_receive(:puts).with("  #{red("✗")} Gemfile is missing in git repository")
        invoke(@main, :check)
      end
    end

    context "when thin gem exists" do
      it "should show that necessary gem exists" do
        $stdout.should_receive(:puts).with("  #{green("✓")} Gem 'thin' is present")
        invoke(@main, :check)
      end
    end

    context "when thin gem doesn't exist" do
      it "should show that necessary gem doesn't exist" do
        Bundler::Definition.stub_chain(:build, :specs, :map).and_return([])
        $stdout.should_receive(:puts).with("  #{red("✗")} Gem 'thin' is missing in the Gemfile")
        invoke(@main, :check)
      end
    end

    context "when config.ru exists" do
      it "should show that config.ru exists" do
        $stdout.should_receive(:puts).with("  #{green("✓")} File config.ru is present")
        invoke(@main, :check)
      end
    end

    context "when config.ru doesn't exist" do
      it "should show that config.ru is neccessary" do
        Shelly::StructureValidator.any_instance.stub(:repo_paths).and_return([])
        $stdout.should_receive(:puts).with("  #{red("✗")} File config.ru is missing")
        invoke(@main, :check)
      end
    end

    context "when mysql gem exists" do
      it "should show that mysql gem is not supported by Shelly Cloud" do
        Bundler::Definition.stub_chain(:build, :specs, :map).and_return(["mysql"])
        $stdout.should_receive(:puts).with("  #{red("✗")} mysql driver present in the Gemfile (not supported on Shelly Cloud)")
        invoke(@main, :check)
      end

      it "should show that mysql2 gem is not supported by Shelly Cloud" do
        Bundler::Definition.stub_chain(:build, :specs, :map).and_return(["mysql2"])
        $stdout.should_receive(:puts).with("  #{red("✗")} mysql driver present in the Gemfile (not supported on Shelly Cloud)")
        invoke(@main, :check)
      end
    end

    context "when bundler raise error" do
      it "should display error message" do
        exception = Bundler::BundlerError.new('Bundler error')
        Bundler::Definition.stub(:build).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Bundler error")
        $stdout.should_receive(:puts).with(red "Try to run `bundle install`")
        lambda {
          invoke(@main, :check)
        }.should raise_error(SystemExit)
      end
    end

    it "should display only errors and warnings when in verbose mode" do
      $stdout.should_not_receive(:puts).with("  #{green("✓")} Gem 'thin' is present")
      $stdout.should_receive(:puts).with("  #{yellow("ϟ")} Gem 'shelly-dependencies' is missing, we recommend to install it\n    See more at https://shellycloud.com/documentation/requirements#shelly-dependencies")
      $stdout.should_receive(:puts).with("  #{red("✗")} Gem 'rake' is missing in the Gemfile")
      $stdout.should_receive(:puts).with("\nFix points marked with #{red("✗")} to run your application on the Shelly Cloud")
      $stdout.should_receive(:puts).with("See more about requirements on https://shellycloud.com/documentation/requirements")
      @main.check(false)
    end
  end

  def setup_project(code_name = "foo")
    @app = Shelly::App.new("#{code_name}-production")
    Shelly::App.stub(:new).and_return(@app)
    FileUtils.mkdir_p("/projects/#{code_name}")
    Dir.chdir("/projects/#{code_name}")
    File.open("Cloudfile", 'w') { |f| f.write("#{code_name}-production:\n") }
  end
end
