require "spec_helper"
require "shelly/app"

describe Shelly::App do
  before do
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @app = Shelly::App.new
    @app.purpose = "staging"
    @app.code_name = "foo-staging"
  end

  describe ".guess_code_name" do
    it "should return name of current working directory" do
      Shelly::App.guess_code_name.should == "foo"
    end
  end

  describe "#add_git_remote" do
    it "should add git remote with proper name and git repository" do
      @app.should_receive(:system).with("git remote add staging git@git.shellycloud.com:foo-staging.git")
      @app.add_git_remote
    end
  end

  describe "#generate_cloudfile" do
    it "should return generated cloudfile" do
      user = mock(:email => "bob@example.com")
      @app.stub(:current_user).and_return(user)
      @app.databases = %w(postgresql mongodb)
      FakeFS.deactivate!
      expected = <<-config
foo-staging:
  ruby: 1.9.2 # 1.9.2 or ree
  environment: production # RAILS_ENV
  monitoring_email:
    - bob@example.com
  domains:
    - foo-staging.winniecloud.com
  servers:
    app1:
      size: large
      thin: 4
      # whenever: on
      # delayed_job: 1
    postgresql:
      size: large
      database:
        - postgresql
    mongodb:
      size: large
      database:
        - mongodb
config
      @app.generate_cloudfile.should == expected
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

  describe "#open_billing_page" do
    it "should open browser window" do
      user = mock(:token => "abc", :email => nil, :password => nil)
      @app.stub(:current_user).and_return(user)
      url = "#{@app.shelly.api_url}/apps/foo-staging/edit_billing?api_key=abc"
      Launchy.should_receive(:open).with(url)
      @app.open_billing_page
    end
  end
end
