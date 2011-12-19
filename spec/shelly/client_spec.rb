require "spec_helper"

describe Shelly::Client::APIError do
  before do
    body = {"message" => "something went wrong", "errors" => [["first", "foo"]], "url" => "https://foo.bar"}
    @error = Shelly::Client::APIError.new(body.to_json)
  end

  it "should return error message" do
    @error.message.should == "something went wrong"
  end

  it "should return array of errors" do
    @error.errors.should == [["first", "foo"]]
  end

  it "should return url" do
    @error.url.should == "https://foo.bar"
  end

  it "should return user friendly string" do
    @error.each_error{|error| error.should == "First foo"}
  end

  describe "#validation?" do
    context "when error is caused by validation errors" do
      it "should return true" do
        body = {"message" => "Validation Failed"}
        error = Shelly::Client::APIError.new(body.to_json)
        error.should be_validation
      end
    end

    context "when error is not caused by validation errors" do
      it "should return false" do
        @error.should_not be_validation
      end
    end
  end

  describe "#unauthorized?" do
    context "when error is caused by unauthorized error" do
      it "should return true" do
        body = {"message" => "Unauthorized"}
        error = Shelly::Client::APIError.new(body.to_json)
        error.should be_unauthorized
      end
    end

    context "when error is not caused by unauthorized" do
      it "should return false" do
        @error.should_not be_unauthorized
      end
    end
  end
end

describe Shelly::Client do
  before do
    ENV['SHELLY_URL'] = nil
    @client = Shelly::Client.new("bob@example.com", "secret")
    @url = "https://#{CGI.escape("bob@example.com")}:secret@admin.winniecloud.com/apiv2"
  end

  describe "#api_url" do
    context "env SHELLY_URL is not set" do
      it "should return default API URL" do
        ENV['SHELLY_URL'].should be_nil
        @client.api_url.should == "https://admin.winniecloud.com/apiv2"
      end
    end

    context "env variable SHELLY_URL is set" do
      it "should return value of env variable SHELLY_URL" do
        ENV['SHELLY_URL'] = "https://example.com/api"
        @client.api_url.should == "https://example.com/api"
      end
    end
  end

  describe "#shellyapp_url" do
    it "should sent get request" do
      @client.should_receive(:get).with("/shellyapp").and_return({"url" => "shellyurl"})
      @client.shellyapp_url.should == "shellyurl"
    end
  end

  describe "#register_user" do
    it "should send post request with login and password" do
      @client.should_receive(:post).with("/users", {:user => {:email => "test@example.com",
        :password => "secret", :ssh_key => "ssh-key Abb"}})
      @client.register_user("test@example.com", "secret", "ssh-key Abb")
    end
  end

  describe "#token" do
    it "should get authentication token" do
      @client.should_receive(:get).with("/token")
      @client.token
    end
  end

  describe "#cloud_logs" do
    it "should send get request" do
      time = Time.now
      FakeWeb.register_uri(:get, @url + "/apps/staging-foo/deploys", :body => [{:failed => false, :created_at => time},
        {:failed => true, :created_at => time+1}].to_json)
      response = @client.cloud_logs("staging-foo")
      response.should == [{"failed"=>false, "created_at"=>time.to_s},
             {"failed"=>true, "created_at"=>(time+1).to_s}]
    end
  end

  describe "#app_configs" do
    it "should send get request" do
      FakeWeb.register_uri(:get, @url + "/apps/staging-foo/configs", :body => [{:created_by_user => true, :path => "config/app.yml"}].to_json)
      response = @client.app_configs("staging-foo")
      response.should == [{"created_by_user" => true, "path" => "config/app.yml"}]
    end
  end

  describe "#create_app" do
    it "should send post with app's attributes" do
      @client.should_receive(:post).with("/apps", :app => {:code_name => "foo", :ruby_version => "1.9.2"})
      @client.create_app(:code_name => "foo", :ruby_version => "1.9.2")
    end
  end

  describe "#app_users" do
    it "should send get request with app code_names" do
      FakeWeb.register_uri(:get, @url + "/apps/staging-foo/users", :body => [{:email => "test@example.com"},
        {:email => "test2@example.com"}].to_json)
      response = @client.app_users("staging-foo")
      response.should == [{"email" => "test@example.com"}, {"email" => "test2@example.com"}]
    end
  end

  describe "#app_ips" do
    it "should send get request with app code_name" do
      FakeWeb.register_uri(:get, @url + "/apps/staging-foo/ips", :body => {:mail_server_ip => "10.0.1.1", :web_server_ip => "88.198.21.187"}.to_json)
      response = @client.app_ips("staging-foo")
      response.should == {"mail_server_ip" => "10.0.1.1", "web_server_ip" => "88.198.21.187"}
    end
  end

  describe "#send_invitation" do
    it "should send post with developer's email" do
      FakeWeb.register_uri(:post, @url + "/apps/staging-foo/collaborations", :body => {}.to_json)
      FakeWeb.register_uri(:post, @url + "/apps/production-foo/collaborations", :body => {}.to_json)
      response = @client.send_invitation("staging-foo", "megan@example.com")
      response.should == {}
    end
  end

  describe "#add_ssh_key" do
    it "should send put with give SSH key" do
      @client.should_receive(:post).with("/ssh_key", {:ssh_key => "abc"})
      @client.add_ssh_key("abc")
    end
  end

  describe "#apps" do
    it "should send get requests for user's applications list" do
      @client.should_receive(:get).with("/apps")
      @client.apps
    end
  end

  describe "#start_cloud" do
    it "should sent post request with cloud's code_name" do
      FakeWeb.register_uri(:put, @url + "/apps/staging-foo/start", :body => {}.to_json)
      response = @client.start_cloud("staging-foo")
      response.should == {}
    end
  end

  describe "#stop_cloud" do
    it "should sent delete request with cloud's code_name" do
      FakeWeb.register_uri(:put, @url + "/apps/staging-foo/stop", :body => {}.to_json)
      response = @client.stop_cloud("staging-foo")
      response.should == {}
    end
  end

  describe "#ssh_key_available?" do
    it "should send get request with ssh key" do
      @client.should_receive(:get).with("/users/new", {:ssh_key => "ssh-key Abb"})
      @client.ssh_key_available?("ssh-key Abb")
    end
  end

  describe "#request_parameters" do
    it "should return hash of resquest parameters" do
      expected = {
        :method   => :post,
        :url      => "#{@client.api_url}/account",
        :headers  => @client.headers,
        :payload  => {:name => "bob"}.to_json,
        :user     => "bob@example.com",
        :password => "secret"
      }
      @client.request_parameters("/account", :post, :name => "bob").should == expected
    end

    it "should not include user credentials when they are blank" do
      client = Shelly::Client.new
      expected = {
        :method => :get,
        :url => "#{@client.api_url}/account",
        :headers => @client.headers,
        :payload => {}.to_json
      }
      client.request_parameters("/account", :get).should == expected
    end
  end

  describe "#request" do
    it "should get request parameters" do
      @client.should_receive(:request_parameters)\
        .with("/account", :get, {:sth => "foo"})\
        .and_return({:method => :get})
      RestClient::Request.should_receive(:execute).with({:method => :get})
      @client.request("/account", :get, {:sth => "foo"})
    end

    it "should pass response to process_response method" do
      response = mock(RestClient::Response)
      request = mock(RestClient::Request)
      @client.should_receive(:process_response).with(response)
      RestClient::Request.stub(:execute).and_yield(response, request)
      @client.request("/account", :get)
    end
  end

  describe "#process_response" do
    before do
      @response = mock(RestClient::Response, :code => 200, :body => "{}", :return! => nil)
      @request = mock(RestClient::Request)
      RestClient::Request.stub(:execute).and_yield(@response, @request)
    end

    it "should not follow redirections" do
      @response.should_receive(:return!)
      @client.get('/account')
    end

    %w(401, 404 422 500).each do |code|
      context "on #{code} response code" do
        it "should raise APIError" do
          @response.stub(:code).and_return(code.to_i)
          @response.stub(:body).and_return({"message" => "random error happened"}.to_json)

          lambda {
            @client.post("/api/apps/flower/command", :body => "puts User.count")
          }.should raise_error(Shelly::Client::APIError, "random error happened")
        end
      end
    end
  end

  describe "#headers" do
    it "should return hash of headers" do
      expected = {
        :accept          => :json,
        :content_type    => :json,
        "shelly-version" => Shelly::VERSION
      }
      @client.headers.should == expected
    end
  end

  describe "#get" do
    it "should make GET request to given path" do
      @client.should_receive(:request).with("/account", :get, {})
      @client.get("/account")
    end
  end

  describe "#post" do
    it "should make POST request to given path with parameters" do
      @client.should_receive(:request).with("/account", :post, :name => "pink-one")
      @client.post("/account", :name => "pink-one")
    end
  end

  describe "#put" do
    it "should make PUT resquest to given path with parameters" do
      @client.should_receive(:request).with("/account", :put, :name => "new-one")
      @client.put("/account", :name => "new-one")
    end
  end

  describe "#delete" do
    it "should make DELETE request to given path with parameters" do
      @client.should_receive(:request).with("/account", :delete, :name => "new-one")
      @client.delete("/account", :name => "new-one")
    end

    it "should make DELETE request to apps with parameters" do
      @client.should_receive(:request).with("/apps/new-one", :delete, {})
      @client.delete("/apps/new-one")
    end
  end
end
