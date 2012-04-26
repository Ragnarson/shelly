require "spec_helper"
require "shelly/app"

describe Shelly::App do
  before do
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @client = mock(:api_url => "https://api.example.com", :shellyapp_url => "http://shellyapp.example.com")
    Shelly::Client.stub(:new).and_return(@client)
    @app = Shelly::App.new
    @app.code_name = "foo-staging"
  end

  describe ".guess_code_name" do
    context "no Cloudfile" do
      it "should return name of current working directory" do
        Shelly::App.guess_code_name.should == "foo-staging"
      end
    end

    context "with Cloudfile" do
      it "should return production" do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\n") }
        Shelly::App.guess_code_name.should == "foo-production"
      end

      it "should return production" do
        File.open("Cloudfile", 'w') {|f| f.write("winnie-test:\n") }
        Shelly::App.guess_code_name.should == "foo-staging"
      end

      it "should return productionNUMBER" do
        File.open("Cloudfile", 'w') {|f| f.write("foo-staging:\nfoo-production:\n") }
        Shelly::App.guess_code_name.should == "foo-production1"
      end
    end
  end

  describe "#databases=" do
    it "should remove 'none' as possible database" do
      @app.databases = %w{none postgresql}
      @app.databases.should == ['postgresql']
    end
  end

  describe "#collaborations" do
    it "should fetch app's users" do
      @client.should_receive(:collaborations).with("foo-staging")
      @app.collaborations
    end
  end

  describe "#add_git_remote" do
    before do
      @app.stub(:git_url).and_return("git@git.shellycloud.com:foo-staging.git")
      @app.stub(:system)
    end

    it "should try to remove existing git remote" do
      @app.should_receive(:system).with("git remote rm foo-staging > /dev/null 2>&1")
      @app.add_git_remote
    end

    it "should add git remote with proper name and git repository" do
      @app.should_receive(:system).with("git remote add foo-staging git@git.shellycloud.com:foo-staging.git")
      @app.add_git_remote
    end
  end

  describe "git_fetch_remote" do
    it "should try to remove existing git remote" do
      @app.should_receive(:system).with("git fetch foo-staging > /dev/null 2>&1")
      @app.git_fetch_remote
    end
  end

  describe "git_add_tracking_branch" do
    it "should try to remove existing git remote" do
      @app.should_receive(:system).with("git checkout -b foo-staging --track foo-staging/master > /dev/null 2>&1")
      @app.git_add_tracking_branch
    end
  end


  describe "git_remote_exist" do
    it "should return true if git remote exist" do
      io = mock(:read => "origin\nfoo-staging")
      IO.should_receive(:popen).with("git remote").and_return(io)
      @app.git_remote_exist?.should be_true
    end
  end

  describe "#configs" do
    it "should get configs from client" do
      @client.should_receive(:app_configs).with("foo-staging").and_return(config_response)
      @app.configs.should == config_response
    end

    it "should return only user config files" do
      @client.should_receive(:app_configs).with("foo-staging").and_return(config_response)
      @app.user_configs.should == [{"path" => "user_created", "created_by_user" => true}]
    end

    it "should return only shelly genereted config files" do
      @client.should_receive(:app_configs).with("foo-staging").and_return(config_response)
      @app.shelly_generated_configs.should == [{"path" => "shelly_created", "created_by_user" => false}]
    end

    def config_response
      [{"path" => "user_created", "created_by_user" => true},
       {"path" => "shelly_created", "created_by_user" => false}]
    end

    it "should get config from client" do
      @client.should_receive(:app_config).with("foo-staging", "path")
      @app.config("path")
    end

    it "should create config using client" do
      @client.should_receive(:app_create_config).with("foo-staging", "path", "content")
      @app.create_config("path", "content")
    end

    it "should update config using client" do
      @client.should_receive(:app_update_config).with("foo-staging", "path", "content")
      @app.update_config("path", "content")
    end

    it "should delete config using client" do
      @client.should_receive(:app_delete_config).with("foo-staging", "path")
      @app.delete_config("path")
    end
  end

  describe "#attributes" do
    before do
      @response = {"web_server_ip" => "192.0.2.1",
                   "mail_server_ip" => "192.0.2.3",
                   "state" => "running",
                   "git_info" => {
                     "deployed_commit_message" => "Commit message",
                     "deployed_commit_sha" => "52e65ed2d085eaae560cdb81b2b56a7d76",
                     "repository_url" => "git@winniecloud.net:example-cloud",
                     "deployed_push_author" => "megan@example.com"}}
      @client.stub(:app).and_return(@response)
    end

    it "should fetch app attributes from API and cache them" do
      @client.should_receive(:app).with("foo-staging").exactly(:once).and_return(@response)
      2.times { @app.attributes }
    end

    describe "#web_server_ip" do
      it "should return web server ip address" do
        @app.web_server_ip.should == "192.0.2.1"
      end
    end

    describe "#mail_server_ip" do
      it "should return mail server ip address" do
        @app.mail_server_ip.should == "192.0.2.3"
      end
    end

    describe "#state" do
      it "should return state of cloud" do
        @app.state.should == "running"
      end
    end

    describe "#git_info" do
      it "should return git info" do
        @app.git_info.should == {
           "deployed_commit_message" => "Commit message",
           "deployed_commit_sha" => "52e65ed2d085eaae560cdb81b2b56a7d76",
           "repository_url" => "git@winniecloud.net:example-cloud",
           "deployed_push_author" => "megan@example.com"}
      end
    end
  end

  describe "#generate_cloudfile" do
    it "should return generated cloudfile for large instance" do
      user = mock(:email => "bob@example.com")
      @app.stub(:current_user).and_return(user)
      @app.databases = %w(postgresql mongodb)
      @app.domains = %w(foo-staging.winniecloud.com foo.example.com)
      @app.size = "large"
      FakeFS.deactivate!
      expected = <<-config
foo-staging:
  ruby_version: 1.9.3 # 1.9.3, 1.9.2 or ree-1.8.7
  environment: production # RAILS_ENV
  monitoring_email: bob@example.com
  domains:
    - foo-staging.winniecloud.com
    - foo.example.com
  servers:
    app1:
      size: large
      thin: 4
      # whenever: on
      # delayed_job: 1
    postgresql:
      size: large
      databases:
        - postgresql
    mongodb:
      size: large
      databases:
        - mongodb
config
      @app.generate_cloudfile.strip.should == expected.strip
    end

    it "should return generated cloudfile for small instance" do
      user = mock(:email => "bob@example.com")
      @app.stub(:current_user).and_return(user)
      @app.databases = %w(postgresql mongodb)
      @app.domains = %w(foo-staging.winniecloud.com foo.example.com)
      @app.size = "small"
      FakeFS.deactivate!
      expected = <<-config
foo-staging:
  ruby_version: 1.9.3 # 1.9.3, 1.9.2 or ree-1.8.7
  environment: production # RAILS_ENV
  monitoring_email: bob@example.com
  domains:
    - foo-staging.winniecloud.com
    - foo.example.com
  servers:
    app1:
      size: small
      thin: 2
      # whenever: on
      # delayed_job: 1
    postgresql:
      size: small
      databases:
        - postgresql
    mongodb:
      size: small
      databases:
        - mongodb
config
      @app.generate_cloudfile.strip.should == expected.strip
    end
  end

  describe "#create_cloudfile" do
    before do
      @app.stub(:generate_cloudfile).and_return("foo-staging:")
    end

    it "should create file if Cloudfile doesn't exist" do
      File.exists?("/projects/foo/Cloudfile").should be_false
      @app.create_cloudfile
      File.exists?("/projects/foo/Cloudfile").should be_true
    end

    it "should append content if Cloudfile exists" do
      File.open("/projects/foo/Cloudfile", "w") { |f| f << "foo-production:\n" }
      @app.create_cloudfile
      File.read("/projects/foo/Cloudfile").strip.should == "foo-production:\nfoo-staging:"
    end
  end

  describe "#cloudfile_path" do
    it "should return path to Cloudfile" do
      @app.cloudfile_path.should == "/projects/foo/Cloudfile"
    end
  end

  describe "#start & #stop" do
    it "should start cloud" do
      @client.should_receive(:start_cloud).with("foo-staging")
      @app.start
    end

    it "should stop cloud" do
      @client.should_receive(:stop_cloud).with("foo-staging")
      @app.stop
    end
  end

  describe "#deploy_logs" do
    it "should list deploy_logs" do
      @client.should_receive(:deploy_logs).with("foo-staging")
      @app.deploy_logs
    end
  end

  describe "#application_logs" do
    it "should list application_logs" do
      @client.should_receive(:application_logs).with("foo-staging").
        and_return({"logs" => ["log1", "log2"]})
      @app.application_logs
    end
  end

  describe "#deploy_log" do
    it "should show log" do
      @client.should_receive(:deploy_log).with("foo-staging", "2011-11-29-11-50-16")
      @app.deploy_log("2011-11-29-11-50-16")
    end
  end

  describe "#database_backup" do
    before do
      @description = {
        "filename" => "backup.tar.gz",
        "size" => 1234,
        "human_size" => "2KB"
      }
      @client.stub(:database_backup).and_return(@description)
    end

    it "should fetch backup from API" do
      @client.should_receive(:database_backup).with("foo-staging", "backup.tar.gz")
      @app.database_backup("backup.tar.gz")
    end

    it "should initialize backup object" do
      backup = @app.database_backup("backup.tar.gz")
      backup.code_name.should == "foo-staging"
      backup.size.should == 1234
      backup.human_size.should == "2KB"
      backup.filename.should == "backup.tar.gz"
    end
  end

  describe "#create" do
    it "should create the app on shelly cloud via API client" do
      @app.code_name = "fooo"
      attributes = {
        :code_name => "fooo"
      }
      @client.should_receive(:create_app).with(attributes).and_return("git_url" => "git@git.shellycloud.com:fooo.git",
        "domains" => %w(fooo.shellyapp.com))
      @app.create
    end

    it "should assign returned git_url, domains, ruby_version and environment" do
      @client.stub(:create_app).and_return("git_url" => "git@git.example.com:fooo.git",
        "domains" => ["fooo.shellyapp.com"], "ruby_version" => "1.9.2", "environment" => "production")
      @app.create
      @app.git_url.should == "git@git.example.com:fooo.git"
      @app.domains.should == ["fooo.shellyapp.com"]
      @app.ruby_version.should == "1.9.2"
      @app.environment.should == "production"
    end
  end

  describe "#redeploy" do
    it "should redeploy app via API" do
      @client.should_receive(:redeploy).with("foo-staging")
      @app.redeploy
    end
  end

  describe "#run" do
    before do
      @response = {
        "result" => "4"
      }
      @client.stub(:command).and_return(@response)
      File.open("to_run.rb", 'w') {|f| f.write("User.count\n") }
    end

    it "should return result of executed code" do
      @client.should_receive(:command).with("foo-staging", "2 + 2", :ruby)
      @app.run("2 + 2").should == "4"
    end

    it "should send contents of file when file exists" do
      @client.should_receive(:command).with("foo-staging", "User.count\n", :ruby)
      @app.run("to_run.rb")
    end
  end

  describe "#rake" do
    it "should return result of rake task" do
      @client.should_receive(:command).with("foo-staging", "db:create", :rake).and_return({"result" => "OK"})
      @app.rake("db:create").should == "OK"
    end
  end

  describe "#to_s" do
    it "should return code_name" do
      @app.to_s.should == "foo-staging"
    end
  end

  describe "#edit_billing_url" do
    it "should return link to edit billing page for app" do
      @app.edit_billing_url.should == "http://shellyapp.example.com/apps/foo-staging/billing/edit"
    end
  end

  describe "#open" do
    it "should open returned domain with launchy" do
      @client.should_receive(:app).with("foo-staging").
        and_return({"domain" => "example.com"})
      Launchy.should_receive(:open).with("http://example.com")
      @app.open
    end
  end

  describe "#node_and_console" do
    it "should fetch instance data from Api" do
      @client.should_receive(:node_and_port).with("foo-staging")
      @app.node_and_port
    end
  end

  describe "#console" do
    it "should run ssh with all parameters" do
      @client.stub(:node_and_port).and_return(
        {"node_ip" => "10.0.0.1", "port" => "40010", "user" => "foo"})
      @app.should_receive(:exec).with("ssh -o StrictHostKeyChecking=no -p 40010 -l foo 10.0.0.1")
      @app.console
    end
  end

  describe "#upload" do
    it "should run rsync with all parameters" do
      @client.stub(:node_and_port).and_return(
        {"node_ip" => "10.0.0.1", "port" => "40010", "user" => "foo"})
      @app.should_receive(:exec).with("rsync -avz -e 'ssh -p 40010' --progress /path foo@10.0.0.1:/srv/glusterfs/disk")
      @app.upload("/path")
    end
  end
end
