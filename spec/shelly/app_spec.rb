require "spec_helper"
require "shelly/app"

describe Shelly::App do
  before do
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @client = mock(:api_url => "https://api.example.com", :shellyapp_url => "http://shellyapp.example.com")
    Shelly::Client.stub(:new).and_return(@client)
    @app = Shelly::App.new('foo-staging')
  end

  describe "#databases=" do
    it "should remove 'none' as possible database" do
      @app.databases = %w{none postgresql}
      @app.databases.should == ['postgresql']
    end
  end

  describe "#add_git_remote" do
    before do
      @app.stub(:git_url).and_return("git@git.shellycloud.com:foo-staging.git")
      @app.stub(:system)
    end

    it "should try to remove existing git remote" do
      @app.should_receive(:system).with("git remote rm shelly > /dev/null 2>&1")
      @app.add_git_remote
    end

    it "should add git remote with proper name and git repository" do
      @app.should_receive(:system).with("git remote add shelly git@git.shellycloud.com:foo-staging.git")
      @app.add_git_remote
    end
  end

  describe "#git_fetch_remote" do
    it "should try to remove existing git remote" do
      @app.should_receive(:system).with("git fetch shelly > /dev/null 2>&1")
      @app.git_fetch_remote
    end
  end

  describe "#git_remote_exist?" do
    it "should return true if git remote exist" do
      io = mock(:read => "origin\nshelly")
      IO.should_receive(:popen).with("git remote").and_return(io)
      @app.git_remote_exist?.should be_true
    end
  end

  describe "#remove_git_remote" do
    context "when git remote exist" do
      it "should remove git remote" do
        @app.should_receive(:system).with("git remote rm remote > /dev/null 2>&1")
        @app.should_receive(:git_remote_name).and_return("remote")
        @app.remove_git_remote
      end
    end

    context "when git remote does not exist" do
      it "should invoke git remote rm" do
        @app.should_not_receive(:system)
        @app.should_receive(:git_remote_name).and_return(nil)
        @app.remove_git_remote
      end
    end
  end

  describe "#git_remote_name" do
    before do
      @client.stub(:app).
        and_return("git_info" => {"repository_url" => "git_url"})
    end

    context "when remote exist" do
      let(:io) { mock(:readlines => ["origin\turl\n",
                                     "shelly\tgit_url\n"]) }

      it "should return remote name" do
        IO.should_receive(:popen).with("git remote -v").and_return(io)
        @app.git_remote_name.should == "shelly"
      end
    end

    context "when remote does not exist" do
      let(:io) { mock(:readlines => ["origin\turl\n",
                                     "shelly\turl\n"]) }

      it "should return nil" do
        IO.should_receive(:popen).with("git remote -v").and_return(io)
        @app.git_remote_name.should be_nil
      end
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

    describe "#config_exists?" do
      before do
        @client.stub(:app_configs => config_response)
      end

      it "should return true when config exists" do
        @app.config_exists?("user_created").should be_true
      end

      it "should return false when config doesn't exist" do
        @app.config_exists?("some/config").should be_false
      end
    end
  end

  describe "#attributes" do
    before do
      @response = {"web_server_ip" => "192.0.2.1",
                   "state" => "running",
                   "maintenance" => false,
                   "organization" => {
                     "credit" => 23.0,
                     "details_present" => true
                   },
                   "git_info" => {
                     "deployed_commit_message" => "Commit message",
                     "deployed_commit_sha" => "52e65ed2d085eaae560cdb81b2b56a7d76",
                     "repository_url" => "git@winniecloud.net:example-cloud",
                     "deployed_push_author" => "megan@example.com"}}
      @client.stub(:app).and_return(@response)
    end

    describe "#credit" do
      it "should return free credit that app has" do
        @app.credit.should == 23.0
      end
    end

    describe "#organization_details_present?" do
      it "should return app's organization's details_present?" do
        @app.organization_details_present?.should == true
      end
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

    describe "#state" do
      it "should return state of cloud" do
        @app.state.should == "running"
      end
    end

    describe "#maintenance?" do
      it "should return false" do
        @app.maintenance?.should be_false
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

  describe "#statistics" do
    before do
      @response = [{"name"=>"app1",
                    "memory" => {"kilobyte"=>"276756", "percent" => "74.1"},
                    "swap" => {"kilobyte" => "44332", "percent" => "2.8"},
                    "cpu" => {"wait" => "0.8", "system" => "0.0", "user" => "0.1"},
                    "load" => {"avg15" => "0.13", "avg05" => "0.15", "avg01" => "0.04"}}]
      @client.stub(:statistics).and_return(@response)
    end

    it "should fetch app statistics from API and cache them" do
      @client.should_receive(:statistics).with("foo-staging").exactly(:once).and_return(@response)
      2.times { @app.statistics }
    end
  end

  describe "#usage" do
    before do
      @response = {
        "filesystem"  => {
          "avg"     => "32 KiB",
          "current" => "64 KiB"
        },
        "database" => {
          "avg"     => "64 KiB",
          "current" => "128 KiB"
        },
        "traffic" => {
          "incoming"  => "32 KiB",
          "outgoing"  => "64 KiB"
        }
      }
      @client.stub(:usage).and_return(@response)
    end

    it "should fetch app usage from API and cache them" do
      @client.should_receive(:usage).with("foo-staging").exactly(:once).and_return(@response)
      2.times { @app.usage }
    end
  end

  describe "#start & #stop" do
    it "should start cloud" do
      @client.should_receive(:start_cloud).with("foo-staging").
        and_return("deployment" => {"id" => "DEPLOYMENT_ID"})
      @app.start.should == "DEPLOYMENT_ID"
    end

    it "should stop cloud" do
      @client.should_receive(:stop_cloud).with("foo-staging").
        and_return("deployment" => {"id" => "DEPLOYMENT_ID"})
      @app.stop.should == "DEPLOYMENT_ID"
    end
  end

  describe "#turned_off?" do
    it "should return true if cloud state is turned_off" do
      @client.should_receive(:app).and_return({'state' => 'turned_off'})
      @app.turned_off?.should be_true
    end
  end

  describe "#in_deploy_failed_state?" do
    context "when application is in deploy_failed state" do
      it "should return true" do
        @client.should_receive(:app).
          and_return({'state' => 'deploy_failed'})
        @app.in_deploy_failed_state?.should be_true
      end
    end

    %w(no_billing no_code turned_off turning_off deploying running).each do |state|
      context "when application is in #{state} state" do
        it "should return false" do
          @client.should_receive(:app).
            and_return({'state' => state})
          @app.in_deploy_failed_state?.should be_false
        end
      end
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
      @client.should_receive(:application_logs).with("foo-staging", {}).
        and_return({"entries" => [["app1", "log1"], ["app2", "log2"]]})
      @app.application_logs
    end
  end

  describe "#deploy_log" do
    it "should show log" do
      @client.should_receive(:deploy_log).with("foo-staging", "2011-11-29-11-50-16")
      @app.deploy_log("2011-11-29-11-50-16")
    end
  end

  describe "#database_backups" do
    it "should add limit parameter" do
      @client.stub_chain(:database_backups, :map)
      @client.should_receive(:database_backups).with("foo-staging")
      @app.database_backups
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
    before { @app.stub(:gemfile_ruby_version) }

    it "should create the app on shelly cloud via API client" do
      @app.code_name = "fooo"

      attributes = {
        :code_name => "fooo",
        :organization_name => nil,
        :zone_name => nil
      }
      @client.should_receive(:create_app).with(attributes).and_return("git_url" => "git@git.shellycloud.com:fooo.git",
        "domains" => %w(fooo.shellyapp.com))
      @app.create
    end

    it "should assign returned git_url, domains, ruby_version and environment" do
      @client.stub(:create_app).and_return("git_url" => "git@git.example.com:fooo.git",
        "domains" => ["fooo.shellyapp.com"], "ruby_version" => "1.9.2", "environment" => "production")
      stub_const('RUBY_PLATFORM', 'i686-linux')
      @app.create
      @app.git_url.should == "git@git.example.com:fooo.git"
      @app.domains.should == ["fooo.shellyapp.com"]
      @app.ruby_version.should == "1.9.2"
      @app.environment.should == "production"
    end

    context "ruby version" do
      before do
        @app.unstub(:gemfile_ruby_version)
        stub_const('RUBY_PLATFORM', 'i686-linux')
        @client.stub(:create_app).and_return("git_url" => "git@git.example.com:fooo.git",
          "domains" => ["fooo.shellyapp.com"], "ruby_version" => "1.9.2", "environment" => "production")
      end

      it "should assign jruby as ruby_version if gem is running under jruby" do
        stub_const('RUBY_PLATFORM', 'java')
        @app.create
        @app.ruby_version.should == "jruby"
      end

      it "should return jruby if engine is set to jruby" do
        Bundler::Definition.stub_chain(:build, :ruby_version).
          and_return(mock(:engine => 'jruby'))

        @app.create
        @app.ruby_version.should == 'jruby'
      end

      it "should return ruby_version from gemfile" do
        Bundler::Definition.stub_chain(:build, :ruby_version).
          and_return(mock(:engine => 'ruby', :version => '1.9.3'))

        @app.create
        @app.ruby_version.should == "1.9.3"
      end
    end
  end

  describe "#redeploy" do
    it "should redeploy app via API" do
      @client.should_receive(:redeploy).with("foo-staging").
        and_return("deployment" => {"id" => "DEPLOYMENT_ID"})
      @app.redeploy.should == "DEPLOYMENT_ID"
    end
  end

  describe "#rake" do
    it "should return result of rake task" do
      @client.stub(:tunnel).and_return(
        {"host" => "console.example.com", "port" => "40010", "user" => "foo"})
      @app.should_receive(:childprocess).with("ssh -o StrictHostKeyChecking=no -p 40010 -l foo -t -t console.example.com rake_runner \"test\"")
      @app.rake("test")
    end
  end

  describe "#dbconsole" do
    it "should return result of dbconsole" do
      @client.stub(:configured_db_server).and_return(
        {"host" => "console.example.com", "port" => "40010", "user" => "foo"})
      @app.should_receive(:childprocess).with("ssh -o StrictHostKeyChecking=no -p 40010 -l foo -t -t console.example.com dbconsole")
      @app.dbconsole
    end
  end

  describe "#mongoconsole" do
    it "should return result of mongoconsole" do
      @client.stub(:configured_db_server).and_return(
        {"host" => "console.example.com", "port" => "40010", "user" => "foo"})
      @app.should_receive(:childprocess).with("ssh -o StrictHostKeyChecking=no -p 40010 -l foo -t -t console.example.com mongo")
      @app.mongoconsole
    end
  end

  describe "#redis_cli" do
    it "should return result of redis-cli" do
      @client.stub(:configured_db_server).and_return(
        {"host" => "console.example.com", "port" => "40010", "user" => "foo"})
      @app.should_receive(:childprocess).with("ssh -o StrictHostKeyChecking=no -p 40010 -l foo -t -t console.example.com redis-cli")
      @app.redis_cli
    end
  end

  describe "#to_s" do
    it "should return code_name" do
      @app.to_s.should == "foo-staging"
    end
  end

  describe "#edit_billing_url" do
    it "should return link to edit billing page for app" do
      @app.stub(:organization_name).and_return("example")
      @app.edit_billing_url.should == "http://shellyapp.example.com/organizations/example/edit"
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

  describe "#console" do
    it "should run ssh with all parameters" do
      @client.stub(:tunnel).and_return(
        {"host" => "console.example.com", "port" => "40010", "user" => "foo"})
      @app.should_receive(:childprocess).with("ssh -o StrictHostKeyChecking=no -p 40010 -l foo -t -t console.example.com ")
      @app.console
    end

    context "when server passed" do
      it "should request console on given server" do
        @client.should_receive(:tunnel).with("foo-staging", "ssh", "app1").and_return({})
        @app.should_receive(:childprocess)
        @app.console("app1")
      end
    end
  end

  describe "#list_files" do
    it "should list files for given subpath in disk" do
      @app.stub(:attributes => {"system_user" => "system_user"})
      @app.should_receive(:ssh).with(:command => "ls -l /home/system_user/disk/foo")
      @app.list_files("foo")
    end
  end

  describe "#upload" do
    it "should run rsync with proper parameters" do
      @app.stub(:attributes => {"system_user" => "system_user"})
      @client.stub(:tunnel).and_return(
        {"host" => "console.example.com", "port" => "40010", "user" => "foo"})
      @app.should_receive(:system).with("rsync --archive --verbose --compress --relative -e 'ssh -o StrictHostKeyChecking=no -p 40010 -l foo' --progress /path console.example.com:/home/system_user/disk/.")
      @app.upload("/path", ".")
    end
  end

  describe "#download" do
    it "should run rsync with proper parameters" do
      @app.stub(:attributes => {"system_user" => "system_user"})
      @client.stub(:tunnel).and_return(
        {"host" => "console.example.com", "port" => "40010", "user" => "foo"})
      @app.should_receive(:system).with("rsync --archive --verbose --compress  -e 'ssh -o StrictHostKeyChecking=no -p 40010 -l foo' --progress console.example.com:/home/system_user/disk/. /tmp")
      @app.download(".", "/tmp")
    end
  end

  describe "#delete_file" do
    it "should delete file over ssh" do
      @app.should_receive(:ssh).with(:command => "delete_file foo/bar")
      @app.delete_file("foo/bar")
    end
  end

  context "certificate" do
    it "#show_cert should query api" do
      @client.should_receive(:cert).with(@app.code_name)
      @app.cert
    end

    it "#create_cert should query api" do
      @client.should_receive(:create_cert).with(@app.code_name, 'crt', 'key')
      @app.create_cert("crt", "key")
    end

    it "#update_cert should query api" do
      @client.should_receive(:update_cert).with(@app.code_name, 'crt', 'key')
      @app.update_cert("crt", "key")
    end
  end

  describe "#create_cloudfile" do
    before do
      @app.environment = "production"
      @app.domains = ["example.com", "another.example.com"]
      @app.size = "large"
      @app.databases = []
      @cloudfile = mock(:code_name= => nil, :ruby_version= => nil,
        :environment= => nil, :domains= => nil, :size= => nil, :thin= => nil,
        :puma= => nil, :databases= => nil, :create => nil)
      Shelly::Cloudfile.should_receive(:new).and_return(@cloudfile)
    end

    it "should create cloudfile with app attributes" do
      @app.ruby_version = "1.9.3"
      @cloudfile.should_receive(:code_name=).with("foo-staging")
      @cloudfile.should_receive(:ruby_version=).with("1.9.3")
      @cloudfile.should_receive(:environment=).with("production")
      @cloudfile.should_receive(:domains=).with(["example.com", "another.example.com"])
      @cloudfile.should_receive(:size=).with("large")
      @cloudfile.should_receive(:thin=).with(4)
      @cloudfile.should_not_receive(:puma=)
      @cloudfile.should_receive(:databases=).with([])
      @cloudfile.should_receive(:create)
      @app.create_cloudfile
    end

    it "should set puma instead of thin under jruby" do
      @app.ruby_version = "jruby"
      @cloudfile.should_not_receive(:thin=)
      @cloudfile.should_receive(:puma=).with(2)
      @app.create_cloudfile
    end
  end

  describe "#databases" do
    before do
      content = {"servers" => {"app1" => {"databases" => ["postgresql", "redis"]},
                               "app2" => {"databases" => ["mongodb"]}}}
      @app.stub(:content).and_return(content)
    end

    it "should return databases in cloudfile" do
      @app.cloud_databases.should =~ ['redis', 'mongodb', 'postgresql']
    end

    it "should return databases except for redis" do
      @app.backup_databases.should =~ ['postgresql', 'mongodb']
    end
  end

  describe "#delayed_job?" do
    it "should return true if present" do
      content = {"servers" => {"app1" => {"delayed_job" => 1}}}
      @app.stub(:content).and_return(content)
      @app.delayed_job?.should be_true
    end

    it "should retrun false if not present" do
      content = {"servers" => {"app1" => {"size" => "small"}}}
      @app.stub(:content).and_return(content)
      @app.delayed_job?.should be_false
    end
  end

  describe "#whenever?" do
    it "should return true if present" do
      content = {"servers" => {"app1" => {"whenever" => true}}}
      @app.stub(:content).and_return(content)
      @app.whenever?.should be_true
    end

    it "should return false if not present" do
      content = {"servers" => {"app1" => {"size" => "small"}}}
      @app.stub(:content).and_return(content)
      @app.whenever?.should be_false
    end
  end

  describe "#sidekiq?" do
    it "should return true if present" do
      content = {"servers" => {"app1" => {"sidekiq" => true}}}
      @app.stub(:content).and_return(content)
      @app.sidekiq?.should be_true
    end

    it "should return false if not present" do
      content = {"servers" => {"app1" => {"size" => "small"}}}
      @app.stub(:content).and_return(content)
      @app.sidekiq?.should be_false
    end
  end

  describe "#thin?" do
    it "should return true if present" do
      content = {"servers" => {"app1" => {"thin" => 1}}}
      @app.stub(:content).and_return(content)
      @app.thin?.should be_true
    end

    it "should return false if not present" do
      content = {"servers" => {"app1" => {"size" => "small"}}}
      @app.stub(:content).and_return(content)
      @app.thin?.should be_false
    end
  end

  describe "#puma?" do
    it "should return true if present" do
      content = {"servers" => {"app1" => {"puma" => true}}}
      @app.stub(:content).and_return(content)
      @app.puma?.should be_true
    end

    it "should return false if not present" do
      content = {"servers" => {"app1" => {"size" => "small"}}}
      @app.stub(:content).and_return(content)
      @app.puma?.should be_false
    end
  end

  describe "#application_logs_tail" do
    it "should execute given block for logs fetched from API" do
      @client.should_receive(:application_logs_tail).with("foo-staging").and_yield("GET / 127.0.0.1")
      out = ""
      @app.application_logs_tail { |logs| out << logs }
      out.should == "GET / 127.0.0.1"
    end
  end

  describe "#deployed?" do
    it "should return true when app has been deployed" do
      @app.stub(:attributes => {"git_info" => {"deployed_commit_sha" => "d1b8bec"}})
      @app.should be_deployed
    end

    it "should return false when app hasn't been deployed yet" do
      @app.stub(:attributes => {"git_info" => {"deployed_commit_sha" => ""}})
      @app.should_not be_deployed
    end
  end

  describe "#pending_commits" do
    it "should return list of not deployed commits" do
      IO.stub_chain(:popen, :read => "c10c5f6\n")
      IO.should_receive(:popen).with(%Q{git log --no-merges --oneline --pretty=format:\"%C(yellow)%h%Creset %s %C(red)(%cr)%Creset\" c213697..c10c5f6}).and_return(mock(:read => "c10c5f6 Some changes\n"))
      @app.stub(:attributes => {"git_info" => {"deployed_commit_sha" => "c213697"}})
      @app.pending_commits.should == "c10c5f6 Some changes"
    end
  end

  describe "#setup_tunnel" do
    it "should setup tunnel with given options" do
      @app.should_receive(:system).with("ssh -o StrictHostKeyChecking=no -p 43000 -l foo -N -L 9999:localhost:5432 console.example.com")
      @app.setup_tunnel({"service" => {"port" => "5432"}, "host" => "console.example.com", "port" => 43000, "user" => "foo"}, 9999)
    end
  end
end
