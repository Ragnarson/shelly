require "spec_helper"
require "shelly/cloudfile"

describe Shelly::Cloudfile do
  before do
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @cloudfile = Shelly::Cloudfile.new
  end

  describe "#content" do
    it "should fetch and parse file content" do
      content = <<-config
foo-staging:
  ruby_version: 1.9.3
  environment: production
  monitoring_email: bob@example.com
  domains:
    - foo-staging.winniecloud.com
  servers:
    app1:
      size: small
      thin: 2
      whenever: on
      delayed_job: 1
      databases:
        - postgresql
config
      File.open("/projects/foo/Cloudfile", "w") { |f| f << content }
      @cloudfile.content.should == {"foo-staging" => {
        "ruby_version" => "1.9.3",
        "environment" => "production",
        "monitoring_email" => "bob@example.com",
        "domains" => ["foo-staging.winniecloud.com"],
        "servers" => { "app1" =>
            {"size" => "small",
             "thin" => 2,
             "whenever" => true,
             "delayed_job" => 1,
             "databases" => ["postgresql"]}
             }
           }
         }
    end

    if RUBY_VERSION >= "1.9"
      it "prints error and quits when 1.9 incompatible syntax is used" do
        $stdout.stub(:puts)

        content = <<-config
foo-staging:
  domains:
    - foo-staging.winniecloud.com
    - *.foo-staging.com
        config

        File.open("/projects/foo/Cloudfile", "w") { |f| f << content }

        $stdout.should_receive(:puts).with("Your Cloudfile has invalid YAML syntax.")

        expect {
          @cloudfile.content
        }.to raise_error(SystemExit)
      end
    end
  end

  describe "#clouds" do
    it "should create Cloud objects" do
      content = <<-config
foo-staging:
  ruby_version: 1.9.3
  servers:
    app1:
      size: small
foo-production:
  environment: production
  servers:
    app1:
      thin: 2
config
      File.open("/projects/foo/Cloudfile", "w") { |f| f << content }
      cloud1 = Shelly::App.should_receive(:new).with("foo-staging")
      cloud2 = Shelly::App.should_receive(:new).with("foo-production")

      @cloudfile.clouds
    end
  end

  describe "#generate" do
    before do
      @cloudfile.code_name = "foo-staging"
      @cloudfile.domains = ["foo-staging.winniecloud.com", "*.foo.example.com"]
      @cloudfile.databases = ["postgresql", "mongodb"]
      @cloudfile.ruby_version = "1.9.3"
      @cloudfile.environment = "production"
      @cloudfile.size = "large"
      @cloudfile.thin = 4
      @cloudfile.stub(:current_user => mock(:email => "bob@example.com"))
    end

    context "for large virtual server" do
      it "should generate sample Cloudfile with given attributes" do
        FakeFS.deactivate!
        expected = <<-config
foo-staging:
  ruby_version: 1.9.3 # 2.0.0, jruby, 1.9.3, 1.9.2 or ree-1.8.7
  environment: production # RAILS_ENV
  monitoring_email: bob@example.com
  domains:
    - foo-staging.winniecloud.com
    - "*.foo.example.com"
  servers:
    app1:
      size: large
      thin: 4
      # delayed_job: 1
      # sidekiq: 1
      # clockwork: on
      # whenever: on
      # elasticsearch: on
      databases:
        - postgresql
        - mongodb
        # - redis
config

        @cloudfile.generate.should == expected
      end
    end

    context "for small virtual server" do
      it "should generate sample Cloudfile with given attributes and 2 thins" do
        FakeFS.deactivate!
        @cloudfile.size = "small"
        @cloudfile.thin = 2
        expected = <<-config
foo-staging:
  ruby_version: 1.9.3 # 2.0.0, jruby, 1.9.3, 1.9.2 or ree-1.8.7
  environment: production # RAILS_ENV
  monitoring_email: bob@example.com
  domains:
    - foo-staging.winniecloud.com
    - "*.foo.example.com"
  servers:
    app1:
      size: small
      thin: 2
      # delayed_job: 1
      # sidekiq: 1
      # clockwork: on
      # whenever: on
      # elasticsearch: on
      databases:
        - postgresql
        - mongodb
        # - redis
config
        @cloudfile.generate.should == expected
      end
    end
  end

  describe "#create" do
    before do
      @cloudfile.stub(:generate).and_return("foo-staging:")
    end

    it "should create file if Cloudfile doesn't exist" do
      File.exists?("/projects/foo/Cloudfile").should be_false
      @cloudfile.create
      File.exists?("/projects/foo/Cloudfile").should be_true
    end

    it "should append content if Cloudfile exists" do
      File.open("/projects/foo/Cloudfile", "w") { |f| f << "foo-production:\n" }
      @cloudfile.create
      File.read("/projects/foo/Cloudfile").strip.should == "foo-production:\nfoo-staging:"
    end
  end
end
