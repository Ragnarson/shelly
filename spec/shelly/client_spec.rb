require "spec_helper"

describe Shelly::Client::APIError do
  before do
    body = {"message" => "Couldn't find Cloud with code_name = fooo",
      "errors" => [["first", "foo"]], "url" => "https://foo.bar"}
    @error = Shelly::Client::APIError.new(404, body)
  end

  it "should return error message" do
    @error.message.should == "Couldn't find Cloud with code_name = fooo"
  end

  it "should return array of errors" do
    @error.errors.should == [["first", "foo"]]
  end

  it "should return url" do
    @error.url.should == "https://foo.bar"
  end

  it "should return user friendly string" do
    @error.each_error { |error| error.should == "First foo" }
  end

  describe "#resource_not_found?" do
    context "on 404 response" do
      it "should return which resource was not found" do
        @error.resource_not_found.should == :cloud
      end
    end

    context "on non 404 response" do
      it "should return nil" do
        error = Shelly::Client::APIError.new(401)
        error.resource_not_found.should be_nil
      end
    end
  end

  describe "#not_found?" do
    it "should return true if response status code is 404" do
      @error.should be_not_found
    end

    it "should return false if response status code is not 404" do
      error = Shelly::Client::APIError.new(500)
      error.should_not be_not_found
    end
  end

  describe "#validation?" do
    context "when error is caused by validation errors" do
      it "should return true" do
        body = {"message" => "Validation Failed"}
        error = Shelly::Client::APIError.new(422, body)
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
        error = Shelly::Client::APIError.new(401)
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
  end

  def api_url(resource = "")
    auth = "#{CGI.escape(@client.email)}:#{@client.password}@"
    "https://#{auth}admin.winniecloud.com/apiv2/#{resource}"
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

  describe "#deploy_logs" do
    it "should send get request" do
      time = Time.now
      FakeWeb.register_uri(:get, api_url("apps/staging-foo/deploys"), :body => [{:failed => false, :created_at => time},
        {:failed => true, :created_at => time+1}].to_json)
      response = @client.deploy_logs("staging-foo")
      response.should == [{"failed"=>false, "created_at"=>time.to_s},
             {"failed"=>true, "created_at"=>(time+1).to_s}]
    end
  end

  describe "#deploy_log" do
    it "should send get request with cloud and log" do
      FakeWeb.register_uri(:get, api_url("apps/staging-foo/deploys/2011-11-29-11-50-16"), :body => {:content => "Log"}.to_json)
      response = @client.deploy_log("staging-foo", "2011-11-29-11-50-16")
      response.should == {"content" => "Log"}
    end
  end

  describe "#app_configs" do
    it "should send get request" do
      FakeWeb.register_uri(:get, api_url("apps/staging-foo/configs"), :body => [{:created_by_user => true, :path => "config/app.yml"}].to_json)
      response = @client.app_configs("staging-foo")
      response.should == [{"created_by_user" => true, "path" => "config/app.yml"}]
    end
  end

  describe "#app_config" do
    it "should send get request" do
      FakeWeb.register_uri(:get, api_url("apps/staging-foo/configs/path"), :body => [{:content => "content", :path => "path"}].to_json)
      response = @client.app_config("staging-foo", "path")
      response.should == [{"content" => "content", "path" => "path"}]
    end
  end

  describe "#app_create_config" do
    it "should send post request" do
      FakeWeb.register_uri(:post, api_url("apps/staging-foo/configs"), :body => {}.to_json, :status => 201)
      response = @client.app_create_config("staging-foo", "path", "content")
      response.should == {}
    end
  end

  describe "#app_update_config" do
    it "should send put request" do
      FakeWeb.register_uri(:put, api_url("apps/staging-foo/configs/path"), :body => {}.to_json)
      response = @client.app_update_config("staging-foo", "path", "content")
      response.should == {}
    end
  end

  describe "#app_delete_config" do
    it "should send delete request" do
      FakeWeb.register_uri(:delete, api_url("apps/staging-foo/configs/path"), :body => {}.to_json)
      response = @client.app_delete_config("staging-foo", "path")
      response.should == {}
    end
  end

  describe "#application_logs" do
    it "should send get request" do
      time = Time.now
      FakeWeb.register_uri(:get, api_url("apps/staging-foo/logs"),
        :body => {:logs => ["application_log_1", "application_log_2"]}.to_json)
      response = @client.application_logs("staging-foo")
      response.should == {"logs" => ["application_log_1", "application_log_2"]}
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
      FakeWeb.register_uri(:get, api_url("apps/staging-foo/users"), :body => [{:email => "test@example.com"},
        {:email => "test2@example.com"}].to_json)
      response = @client.app_users("staging-foo")
      response.should == [{"email" => "test@example.com"}, {"email" => "test2@example.com"}]
    end
  end
  
  describe "#app" do
    it "should fetch app from API" do
      FakeWeb.register_uri(:get, api_url("apps/staging-foo"), 
        :body => {:web_server_ip => "192.0.2.1", :mail_server_ip => "192.0.2.3"}.to_json)
      response = @client.app("staging-foo")
      response.should == {"web_server_ip" => "192.0.2.1", "mail_server_ip" => "192.0.2.3"}
    end
  end

  describe "#send_invitation" do
    it "should send post with developer's email" do
      FakeWeb.register_uri(:post, api_url("apps/staging-foo/collaborations"), :body => {}.to_json)
      FakeWeb.register_uri(:post, api_url("apps/production-foo/collaborations"), :body => {}.to_json)
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
      FakeWeb.register_uri(:put, api_url("apps/staging-foo/start"), :body => {}.to_json)
      response = @client.start_cloud("staging-foo")
      response.should == {}
    end
  end

  describe "#stop_cloud" do
    it "should sent delete request with cloud's code_name" do
      FakeWeb.register_uri(:put, api_url("apps/staging-foo/stop"), :body => {}.to_json)
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

  describe "#database_backup" do
    it "should fetch backup description from API" do
      expected = {
        "filename" => @filename,
        "size" => 1234,
        "human_size" => "2KB"
      }
      filename = "2011.11.26.04.00.10.foo.postgres.tar.gz"
      url = api_url("apps/foo/database_backups/#{filename}")
      FakeWeb.register_uri(:get, url, :body => expected.to_json)

      @client.database_backup("foo", filename).should == expected
    end
  end

  describe "#download_backup" do
    before do
      @filename = "2011.11.26.04.00.10.foo.postgres.tar.gz"
      url = api_url("apps/foo/database_backups/#{@filename}")
      response = Net::HTTPResponse.new('', '', '')
      # Streaming
      response.stub(:read_body).and_yield("aaa").and_yield("bbbbb").and_yield("dddf")
      FakeWeb.register_uri(:get, url, :response => response)
    end

    it "should write streamed database backup to file" do
      @client.download_backup("foo", @filename)
      File.read(@filename).should == %w(aaa bbbbb dddf).join
    end

    it "should execute progress_callback with size of every chunk" do
      progress = mock(:update => true)
      progress.should_receive(:update).with(3)
      progress.should_receive(:update).with(5)
      progress.should_receive(:update).with(4)

      callback = lambda { |size| progress.update(size) }

      @client.download_backup("foo", @filename, callback)
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
    
    it "should return empty hash if response is not a valid JSON" do
      JSON.should_receive(:parse).with("").and_raise(JSON::ParserError)
      @response.stub(:code).and_return("204")
      @response.stub(:body).and_return("")
      @client.post("/api/apps/flower").should == {}
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
