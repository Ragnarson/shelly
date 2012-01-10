require "spec_helper"
require "shelly/cli/main"

describe Shelly::CLI::Main do
  before do
    FileUtils.stub(:chmod)
    @main = Shelly::CLI::Main.new
    Shelly::CLI::Main.stub(:new).and_return(@main)
    @client = mock
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
      expected = <<-OUT
Tasks:
  shelly add                # Add a new cloud
  shelly backup <command>   # Manage database backups
  shelly config <command>   # Manage application configuration files
  shelly delete             # Delete the cloud
  shelly deploys <command>  # View deploy logs
  shelly execute [CODE]     # Run code on one of application servers
  shelly help [TASK]        # Describe available tasks or one specific task
  shelly ip                 # List cloud's IP addresses
  shelly list               # List available clouds
  shelly login [EMAIL]      # Log into Shelly Cloud
  shelly logout             # Logout from Shelly Cloud
  shelly logs               # Show latest application logs
  shelly redeploy           # Redeploy application
  shelly register [EMAIL]   # Register new account
  shelly start              # Start the cloud
  shelly stop               # Stop the cloud
  shelly user <command>     # Manage collaborators
  shelly version            # Display shelly version

Options:
  [--debug]  # Show debug information
OUT
      out = IO.popen("bin/shelly --debug").read.strip
      out.should == expected.strip
    end

    it "should display options in help for logs" do
      expected = <<-OUT
Usage:
  shelly logs

Options:
  -c, [--cloud=CLOUD]  # Specify cloud
      [--debug]        # Show debug information

Show latest application logs
OUT
      out = IO.popen("bin/shelly help logs").read.strip
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
        invoke(@main, :register)
      }.should raise_error(SystemExit)
    end

    it "should check ssh key in database" do
      @user.stub(:ssh_key_registered?).and_raise(Shelly::Client::ConflictException.new)
      $stdout.should_receive(:puts).with("\e[31mUser with your ssh key already exists.\e[0m")
      $stdout.should_receive(:puts).with("\e[31mYou can login using: shelly login [EMAIL]\e[0m")
      lambda {
        invoke(@main, :register)
      }.should raise_error(SystemExit)
    end

    it "should ask for email, password and password confirmation" do
      $stdout.should_receive(:print).with("Email: ")
      $stdout.should_receive(:print).with("Password: ")
      $stdout.should_receive(:print).with("Password confirmation: ")
      fake_stdin(["better@example.com", "secret", "secret"]) do
        invoke(@main, :register)
      end
    end

    it "should suggest email and use it if user enters blank email" do
      Shelly::User.stub(:guess_email).and_return("kate@example.com")
      $stdout.should_receive(:print).with("Email (kate@example.com - default): ")
      @client.should_receive(:register_user).with("kate@example.com", "secret", "ssh-key AAbbcc")
      fake_stdin(["", "secret", "secret"]) do
        invoke(@main, :register)
      end
    end

    it "should use email provided by user" do
      @client.should_receive(:register_user).with("better@example.com", "secret", "ssh-key AAbbcc")
      fake_stdin(["better@example.com", "secret", "secret"]) do
        invoke(@main, :register)
      end
    end

    it "should not ask about email if it's provided as argument" do
      $stdout.should_receive(:puts).with("Registering with email: kate@example.com")
      fake_stdin(["secret", "secret"]) do
        invoke(@main, :register, "kate@example.com")
      end
    end

    context "when user enters blank email" do
      it "should show error message and exit with 1" do
        Shelly::User.stub(:guess_email).and_return("")
        $stdout.should_receive(:puts).with("\e[31mEmail can't be blank, please try again\e[0m")
        lambda {
          fake_stdin(["", "bob@example.com", "only-pass", "only-pass"]) do
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
        fake_stdin(["kate@example.com", "secret", "secret"]) do
          invoke(@main, :register)
        end
      end
    end

    context "public SSH key doesn't exist" do
      it "should register user without the public SSH key" do
        @user.stub(:ssh_key_registered?)
        FileUtils.rm_rf(@key_path)
        $stdout.should_not_receive(:puts).with("Uploading your public SSH key from #{@key_path}")
        fake_stdin(["kate@example.com", "secret", "secret"]) do
          invoke(@main, :register)
        end
      end
    end

    context "on successful registration" do
      it "should display message about registration and email address confirmation" do
        @client.stub(:register_user).and_return(true)
        $stdout.should_receive(:puts).with("Successfully registered!")
        $stdout.should_receive(:puts).with("Check you mailbox for email address confirmation")
        fake_stdin(["kate@example.com", "pass", "pass"]) do
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
          fake_stdin(["kate@example.com", "pass", "pass"]) do
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
        $stdout.should_receive(:puts).with("Login successful")
        fake_stdin(["megan@example.com", "secret"]) do
          invoke(@main, :login)
        end
      end

      it "should accept email as parameter" do
        $stdout.should_receive(:puts).with("Login successful")
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
      @app.stub(:generate_cloudfile).and_return("Example Cloudfile")
      @app.stub(:open_billing_page)
      @app.stub(:git_url).and_return("git@git.shellycloud.com:foooo.git")
      Shelly::App.stub(:inside_git_repository?).and_return(true)
      Shelly::App.stub(:new).and_return(@app)
      @client.stub(:token).and_return("abc")
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
        it "should show help and exit if not all options are passed" do
          $stdout.should_receive(:puts).with("\e[31mTry 'shelly help add' for more information\e[0m")
          @main.options = {"code-name" => "foo"}
          lambda {
            invoke(@main, :add)
          }.should raise_error(SystemExit)
        end

        it "should exit if databases are not valid" do
          $stdout.should_receive(:puts).with("\e[31mTry 'shelly help add' for more information\e[0m")
          @main.options = {"code-name" => "foo", :databases => ["not existing"], :domains => "foo.example.com"}
          lambda {
            invoke(@main, :add)
          }.should raise_error(SystemExit)
        end
      end

      context "valid params" do
        it "should create app on shelly cloud" do
          @app.should_receive(:create)
          @main.options = {"code-name" => "foo", "databases" => ["postgresql"], "domains" => ["foo.example.com"]}
          invoke(@main, :add)
        end
      end
    end

    it "should use code name provided by user" do
      $stdout.should_receive(:print).with("Cloud code name (foo-production - default): ")
      @app.should_receive(:code_name=).with("mycodename")
      fake_stdin(["mycodename", ""]) do
        invoke(@main, :add)
      end
    end

    context "when user provided empty code name" do
      it "should use 'current_dirname-purpose' as default" do
        $stdout.should_receive(:print).with("Cloud code name (foo-production - default): ")
        @app.should_receive(:code_name=).with("foo-production")
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
        @app.should_receive(:databases=).with(["postgresql"])
        fake_stdin(["", "postgresql, none"]) do
          invoke(@main, :add)
        end
      end
    end

    it "should create the app on shelly cloud" do
      @app.should_receive(:create)
      fake_stdin(["", ""]) do
        invoke(@main, :add)
      end
    end

    it "should display validation errors if they are any" do
      body = {"message" => "Validation Failed", "errors" => [["code_name", "has been already taken"]]}
      exception = Shelly::Client::ValidationException.new(body)
      @app.should_receive(:create).and_raise(exception)
      $stdout.should_receive(:puts).with("\e[31mCode name has been already taken\e[0m")
      $stdout.should_receive(:puts).with("\e[31mFix erros in the below command and type it again to create your cloud\e[0m")
      $stdout.should_receive(:puts).with("\e[31mshelly add --code-name=foo-production --databases=postgresql --domains=foo-production.shellyapp.com\e[0m")
      lambda {
        fake_stdin(["", ""]) do
          invoke(@main, :add)
        end
      }.should raise_error(SystemExit)
    end

    it "should add git remote" do
      $stdout.should_receive(:puts).with("\e[32mAdding remote production git@git.shellycloud.com:foooo.git\e[0m")
      @app.should_receive(:add_git_remote)
      fake_stdin(["foooo", ""]) do
        invoke(@main, :add)
      end
    end

    it "should create Cloudfile" do
      File.exists?("/projects/foo/Cloudfile").should be_false
      fake_stdin(["foooo", ""]) do
        invoke(@main, :add)
      end
      File.read("/projects/foo/Cloudfile").should == "Example Cloudfile"
    end

    it "should browser window with link to edit billing information" do
      $stdout.should_receive(:puts).with("\e[32mProvide billing details. Opening browser...\e[0m")
      @app.should_receive(:open_billing_page)
      fake_stdin(["foooo", ""]) do
        invoke(@main, :add)
      end
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
      $stdout.should_receive(:puts).with("\e[32mDeploy to production using:\e[0m")
      $stdout.should_receive(:puts).with("  git push production master")
      fake_stdin(["foooo", "none"]) do
        invoke(@main, :add)
      end
    end
  end

  describe "#list" do
    before do
      @user = Shelly::User.new
      @client.stub(:token).and_return("abc")
      @client.stub(:apps).and_return([{"code_name" => "abc", "state" => "running"},
         {"code_name" => "fooo", "state" => "deploy_failed"}])
      Shelly::User.stub(:new).and_return(@user)
    end

    it "should ensure user has logged in" do
      hooks(@main, :list).should include(:logged_in?)
    end

    it "should display user's clouds" do
      $stdout.should_receive(:puts).with("\e[32mYou have following clouds available:\e[0m")
      $stdout.should_receive(:puts).with(/abc\s+\|  running/)
      $stdout.should_receive(:puts).with(/fooo\s+\|  deploy failed \(Support has been notified\)/)
      invoke(@main, :list)
    end

    it "should display info that user has no clouds" do
      @client.stub(:apps).and_return([])
      $stdout.should_receive(:puts).with("\e[32mYou have no clouds yet\e[0m")
      invoke(@main, :list)
    end

    it "should have a 'status' alias" do
      @client.stub(:apps).and_return([])
      $stdout.should_receive(:puts).with("\e[32mYou have no clouds yet\e[0m")
      invoke(@main, :status)
    end
  end

  describe "#start" do
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

    # This spec tests cloudfile_present? hook
    it "should exit if there is no Cloudfile" do
      File.delete("Cloudfile")
      $stdout.should_receive(:puts).with("\e[31mNo Cloudfile found\e[0m")
      lambda {
        invoke(@main, :start)
      }.should raise_error(SystemExit)
    end

    it "should ensure user has logged in" do
      hooks(@main, :start).should include(:logged_in?)
    end

    it "should exit if user doesn't have access to clouds in Cloudfile" do
      exception = Shelly::Client::NotFoundException.new("resource" => "cloud")
      @client.stub(:start_cloud).and_raise(exception)
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
      lambda { invoke(@main, :start) }.should raise_error(SystemExit)
    end

    context "single cloud in Cloudfile" do
      it "should start the cloud" do
        @client.stub(:start_cloud)
        $stdout.should_receive(:puts).with(green "Starting cloud foo-production. Check status with:")
        $stdout.should_receive(:puts).with("  shelly list")
        invoke(@main, :start)
      end
    end

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
        $stdout.should_receive(:puts).with(green "Starting cloud foo-staging. Check status with:")
        $stdout.should_receive(:puts).with("  shelly list")
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
        $stdout.should_receive(:puts).with("  git push production master")
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

      it "should open billing page" do
        raise_conflict("state" => "no_billing")
        $stdout.should_receive(:puts).with(red "Please fill in billing details to start foo-production. Opening browser.")
        @app.should_receive(:open_billing_page)
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

    it "should ensure that Cloudfile is present" do
      hooks(@main, :stop).should include(:cloudfile_present?)
    end

    it "should exit if user doesn't have access to clouds in Cloudfile" do
      @client.stub(:stop_cloud).and_raise(Shelly::Client::NotFoundException.new("resource" => "cloud"))
      $stdout.should_receive(:puts).with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
      lambda { invoke(@main, :stop) }.should raise_error(SystemExit)
    end

    context "single cloud in Cloudfile" do
      it "should start the cloud" do
        @client.stub(:stop_cloud)
        $stdout.should_receive(:puts).with("Cloud 'foo-production' stopped")
        invoke(@main, :stop)
      end
    end

    context "multiple clouds in Cloudfile" do
      before do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show information to start specific cloud and exit" do
        $stdout.should_receive(:puts).with(red "You have multiple clouds in Cloudfile.")
        $stdout.should_receive(:puts).with("Select cloud using `shelly stop --cloud foo-production`")
        $stdout.should_receive(:puts).with("Available clouds:")
        $stdout.should_receive(:puts).with(" * foo-production")
        $stdout.should_receive(:puts).with(" * foo-staging")
        lambda { invoke(@main, :stop) }.should raise_error(SystemExit)
      end

      it "should fetch from command line which cloud to start" do
        @client.should_receive(:stop_cloud).with("foo-staging")
        $stdout.should_receive(:puts).with("Cloud 'foo-staging' stopped")
        @main.options = {:cloud => "foo-staging"}
        invoke(@main, :stop)
      end
    end
  end

  describe "#ip" do
    before do
      File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
      @main.stub(:logged_in?).and_return(true)
    end

    it "should ensure user has logged in" do
      hooks(@main, :ip).should include(:logged_in?)
    end

    it "should ensure that Cloudfile is present" do
      hooks(@main, :ip).should include(:cloudfile_present?)
    end

    context "on success" do
      it "should display mail and web server ip's" do
        @client.stub(:app).and_return(response)
        $stdout.should_receive(:puts).with("\e[32mCloud foo-production:\e[0m")
        $stdout.should_receive(:puts).with("  Web server IP: 22.22.22.22")
        $stdout.should_receive(:puts).with("  Mail server IP: 11.11.11.11")
        invoke(@main, :ip)
      end
    end

    def response
      {'mail_server_ip' => '11.11.11.11', 'web_server_ip' => '22.22.22.22'}
    end

    context "on failure" do
      it "should raise an error if user does not have access to cloud" do
        exception = Shelly::Client::NotFoundException.new("resource" => "cloud")
        @client.stub(:app).and_raise(exception)
        $stdout.should_receive(:puts).with(red "You have no access to 'foo-staging' cloud defined in Cloudfile")
        invoke(@main, :ip)
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

    context "when cloud given in option doesn't exist" do
      before do
        File.open("Cloudfile", 'w') {|f|
          f.write("foo-staging:\n") }
      end

      it "should raise Client::NotFoundException" do
        exception = Shelly::Client::NotFoundException.new("resource" => "cloud")
        @app.stub(:delete).and_raise(exception)
        $stdout.should_receive(:puts).with(red "You have no access to 'foo-bar' cloud defined in Cloudfile")
        lambda{
          fake_stdin(["yes", "yes", "yes"]) do
            @main.options = {:cloud => "foo-bar"}
            invoke(@main, :delete)
          end
        }.should raise_error(SystemExit)
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
      @user = Shelly::User.new
      @client.stub(:token).and_return("abc")
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') { |f| f.write("foo-production:\n") }
      Shelly::User.stub(:new).and_return(@user)
      @client.stub(:apps).and_return([{"code_name" => "foo-production"},
                                     {"code_name" => "foo-staging"}])
      @app = Shelly::App.new
      Shelly::App.stub(:new).and_return(@app)
    end

    it "should ensure user has logged in" do
      hooks(@main, :logs).should include(:logged_in?)
    end

    it "should ensure that Cloudfile is present" do
      hooks(@main, :logs).should include(:cloudfile_present?)
    end

    it "should exit if user doesn't have access to clouds in Cloudfile" do
      exception = Shelly::Client::NotFoundException.new("resource" => "cloud")
      @client.stub(:application_logs).and_raise(exception)
      $stdout.should_receive(:puts).
        with(red "You have no access to 'foo-production' cloud defined in Cloudfile")
      lambda { invoke(@main, :logs) }.should raise_error(SystemExit)
    end

    context "single cloud in Cloudfile" do
      it "should show logs for the cloud" do
        @client.stub(:application_logs).and_return(["log1"])
        $stdout.should_receive(:puts).with(green "Cloud foo-production:")
        $stdout.should_receive(:puts).with(green "Instance 1:")
        $stdout.should_receive(:puts).with("log1")
        invoke(@main, :logs)
      end
    end

    context "multiple clouds in Cloudfile" do
      before do
        File.open("Cloudfile", 'w') {|f|
          f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show information to print logs for specific cloud and exit" do
        $stdout.should_receive(:puts).with(red "You have multiple clouds in Cloudfile.")
        $stdout.should_receive(:puts).with("Select cloud using `shelly logs --cloud foo-production`")
        $stdout.should_receive(:puts).with("Available clouds:")
        $stdout.should_receive(:puts).with(" * foo-production")
        $stdout.should_receive(:puts).with(" * foo-staging")
        lambda { invoke(@main, :logs) }.should raise_error(SystemExit)
      end

      it "should fetch from command line which cloud to start" do
        @client.should_receive(:application_logs).with("foo-staging").
          and_return(["log1"])
        $stdout.should_receive(:puts).with(green "Cloud foo-staging:")
        $stdout.should_receive(:puts).with(green "Instance 1:")
        $stdout.should_receive(:puts).with("log1")
        @main.options = {:cloud => "foo-staging"}
        invoke(@main, :logs)
      end
    end

    context "multiple instances" do
      it "should show logs from each instance" do
        @client.stub(:application_logs).and_return(["log1", "log2"])
        $stdout.should_receive(:puts).with(green "Cloud foo-production:")
        $stdout.should_receive(:puts).with(green "Instance 1:")
        $stdout.should_receive(:puts).with("log1")
        $stdout.should_receive(:puts).with(green "Instance 2:")
        $stdout.should_receive(:puts).with("log2")
        invoke(@main, :logs)
      end
    end
  end

  describe "#execute" do
    before do
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') {|f| f.write("foo-production:\n") }
      @user = Shelly::User.new
      @user.stub(:token)
      Shelly::User.stub(:new).and_return(@user)
      @client.stub(:apps).and_return([{"code_name" => "foo-production"},
                                     {"code_name" => "foo-staging"}])
      @app = Shelly::App.new
      Shelly::App.stub(:new).and_return(@app)
      File.open("to_execute.rb", 'w') {|f| f.write("User.count") }
    end

    it "should ensure user has logged in" do
      hooks(@main, :execute).should include(:logged_in?)
    end

    context "single cloud in Cloudfile" do
      it "should execute code for the cloud" do
        @client.should_receive(:run).with("foo-production", "User.count").
          and_return({"result" => "3"})
        $stdout.should_receive(:puts).with("3")
        invoke(@main, :execute, "to_execute.rb")
      end
    end

    context "multiple clouds in Cloudfile" do
      before do
        File.open("Cloudfile", 'w') {|f|
          f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show information to print logs for specific cloud and exit" do
        $stdout.should_receive(:puts).
          with(red "You have multiple clouds in Cloudfile.")
        $stdout.should_receive(:puts).
          with("Select cloud using `shelly execute --cloud foo-production`")
        $stdout.should_receive(:puts).with("Available clouds:")
        $stdout.should_receive(:puts).with(" * foo-production")
        $stdout.should_receive(:puts).with(" * foo-staging")
        lambda { invoke(@main, :execute, "to_execute.rb") }.should raise_error(SystemExit)
      end

      it "should fetch from command line which cloud to start" do
        @client.should_receive(:run).with("foo-staging", "User.count").
          and_return({"result" => "3"})
        $stdout.should_receive(:puts).with("3")
        @main.options = {:cloud => "foo-staging"}
        invoke(@main, :execute, "to_execute.rb")
      end

      it "should run code when no file from parameter is found" do
        @client.should_receive(:run).with("foo-staging", "2 + 2").
          and_return({"result" => "4"})
        $stdout.should_receive(:puts).with("4")
        @main.options = {:cloud => "foo-staging"}
        invoke(@main, :execute, "2 + 2")
      end
    end

    context "cloud is not running" do
      it "should print error" do
        @client.should_receive(:run).with("foo-staging", "2 + 2").
          and_raise(Shelly::Client::APIException.new(
            {"message" => "App not running"}, 504))
        $stdout.should_receive(:puts).
          with(red "Cloud foo-staging is not running. Cannot run code.")
        @main.options = {:cloud => "foo-staging"}
        lambda { invoke(@main, :execute, "2 + 2") }.should raise_error(SystemExit)
      end
    end
  end

  describe "#redeploy" do
    before do
      @user = Shelly::User.new
      @client.stub(:token).and_return("abc")
      @app = Shelly::App.new
      Shelly::App.stub(:new).and_return(@app)
      FileUtils.mkdir_p("/projects/foo")
      Dir.chdir("/projects/foo")
      File.open("Cloudfile", 'w') { |f| f.write("foo-production:\n") }
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

    context "on multiple clouds in Cloudfile" do
      before do
        File.open("Cloudfile", 'w') { |f| f.write("foo-staging:\nfoo-production:\n") }
      end

      it "should show information to redeploy application for specific cloud and exit" do
        $stdout.should_receive(:puts).with(red "You have multiple clouds in Cloudfile.")
        $stdout.should_receive(:puts).with("Select cloud using `shelly redeploy --cloud foo-production`")
        $stdout.should_receive(:puts).with("Available clouds:")
        $stdout.should_receive(:puts).with(" * foo-production")
        $stdout.should_receive(:puts).with(" * foo-staging")
        lambda { invoke(@main, :redeploy) }.should raise_error(SystemExit)
      end

      it "should fetch from command line which cloud to redeploy application for" do
        @client.should_receive(:redeploy).with("foo-staging")
        $stdout.should_receive(:puts).with(green "Redeploying your application for cloud 'foo-staging'")
        @main.options = {:cloud => "foo-staging"}
        invoke(@main, :redeploy)
      end
    end
  end
end
