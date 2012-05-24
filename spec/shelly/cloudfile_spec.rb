require "spec_helper"
require "shelly/cloudfile"

describe Shelly::Cloudfile do
  before do
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @hash = {:code_name => {:code => "test"}}
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @cloudfile = Shelly::Cloudfile.new
  end

  it "should allow improper yaml that works with syck" do
    yaml = %Q{domains:
  - *.example.com
  - example.com
    }
    expect {
      yaml = YAML.load(yaml)
    }.to_not raise_error
    yaml.should == {"domains" => ["*.example.com", "example.com"]}
  end

  describe "#generate" do
    before do
      @cloudfile.code_name = "foo-staging"
      @cloudfile.domains = ["foo-staging.winniecloud.com", "foo.example.com"]
      @cloudfile.databases = ["postgresql", "mongodb"]
      @cloudfile.ruby_version = "1.9.3"
      @cloudfile.environment = "production"
      @cloudfile.size = "large"
      @cloudfile.stub(:current_user => mock(:email => "bob@example.com"))
    end

    context "for large instance" do
      it "should generate sample Cloudfile with given attributes" do
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
      databases:
        - postgresql
        - mongodb
config

        @cloudfile.generate.should == expected
      end
    end

    context "for small instance" do
      it "should generate sample Cloudfile with given attributes and 2 thins" do
        FakeFS.deactivate!
        @cloudfile.size = "small"
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
      databases:
        - postgresql
        - mongodb
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
