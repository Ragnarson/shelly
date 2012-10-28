require "spec_helper"

describe Shelly::Client::NotFoundException do
  describe "#resource" do
    it "should return name of not found resource" do
      message = {"resource" => "log"}
      exception = Shelly::Client::NotFoundException.new(message)
      exception.resource.should == :log
    end
  end
end

describe Shelly::Client::ValidationException do
  before do
    @body = {"message" => "Validation Failed",
      "errors" => [["first", "foo"]], "url" => "https://foo.bar"}
    @exception = Shelly::Client::ValidationException.new(@body)
  end

  describe "#errors" do
    it "should return errors array" do
      @exception.errors.should == [["first", "foo"]]
    end
  end

  describe "#each_error" do
    it "should return user friendly string" do
      @exception.each_error { |error| error.should == "First foo" }
    end
  end
end

describe Shelly::Client::APIException do
  before do
    body = {"message" => "Not Found",
      "errors" => [["first", "foo"]], "url" => "https://foo.bar"}
    @error = Shelly::Client::APIException.new(body)
  end

  describe "#[]" do
    it "should return value of given key from response body" do
      @error["message"].should == "Not Found"
      @error[:message].should == "Not Found"
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
    "https://#{auth}api.shellycloud.com/apiv2/#{resource}"
  end

  describe "#api_url" do
    context "env SHELLY_URL is not set" do
      it "should return default API URL" do
        ENV['SHELLY_URL'].should be_nil
        @client.api_url.should == "https://api.shellycloud.com/apiv2"
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
      FakeWeb.register_uri(:get, api_url("apps/staging-foo/deployment_logs"), :body => [{:failed => false, :created_at => time},
        {:failed => true, :created_at => time+1}].to_json)
      response = @client.deploy_logs("staging-foo")
      response.should == [{"failed"=>false, "created_at"=>time.to_s},
             {"failed"=>true, "created_at"=>(time+1).to_s}]
    end
  end

  describe "#deploy_log" do
    it "should send get request with cloud and log" do
      FakeWeb.register_uri(:get, api_url("apps/staging-foo/deployment_logs/2011-11-29-11-50-16"), :body => {:content => "Log"}.to_json)
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
      FakeWeb.register_uri(:get, api_url("apps/staging-foo/application_logs"),
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

  describe "#organizations" do
    it "should fetch organizations from API" do
      FakeWeb.register_uri(:get, api_url("organizations"),
       :body => [{:name => "org1", :app_code_names => ["app1"]},
                 {:name => "org2", :app_code_names => ["app2"]}].to_json)
      response = @client.organizations
      response.should == [{"name" => "org1", "app_code_names" => ["app1"]},
                          {"name" => "org2", "app_code_names" => ["app2"]}]
    end
  end

  describe "#organization" do
    it "should fetch organization from API" do
      FakeWeb.register_uri(:get, api_url("organizations/foo-org"),
        :body => {:name => "org1", :app_code_names => ["app1"]}.to_json)
      response = @client.organization("foo-org")
      response.should == {"name" => "org1", "app_code_names" => ["app1"]}
    end
  end

  describe "#members" do
    it "should send get request with app code_names" do
      FakeWeb.register_uri(:get, api_url("organizations/staging-foo/memberships"),
        :body => [{:email => "test@example.com", :active => true},
                  {:email => "test2@example.com", :active => false}].to_json)
      response = @client.members("staging-foo")
      response.should == [{"email" => "test@example.com", 'active' => true},
                          {"email" => "test2@example.com", 'active' => false}]
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

  describe "#statistics" do
    it "should fetch app statistics from API" do
      @body = [{:name => "app1",
                :memory => {:kilobyte => "276756", :percent => "74.1"},
                :swap => {:kilobyte => "44332", :percent => "2.8"},
                :cpu => {:wait => "0.8", :system => "0.0", :user => "0.1"},
                :load => {:avg15 => "0.13", :avg05 => "0.15", :avg01 => "0.04"}}]
      FakeWeb.register_uri(:get, api_url("apps/staging-foo/statistics"),
        :body => @body.to_json)
      response = @client.statistics("staging-foo")
      response.should == [{"name" => "app1",
                           "memory" => {"kilobyte" => "276756", "percent" => "74.1"},
                           "swap" => {"kilobyte" => "44332", "percent" => "2.8"},
                           "cpu" => {"wait" => "0.8", "system" => "0.0", "user" => "0.1"},
                           "load" => {"avg15" =>"0.13", "avg05" => "0.15", "avg01" => "0.04"}}]
    end
  end

  describe "#command" do
    it "should send post request with app code_name, body and type" do
      @client.should_receive(:post).with("/apps/staging-foo/command",
        {:body => "2 + 2", :type => :ruby}).and_return({"result" => "4"})
      response = @client.command("staging-foo", "2 + 2", :ruby)
      response.should == {"result" => "4"}
    end
  end

  describe "#console" do
    it "should fetch instance data from API" do
      body = {:port => "40010", :host => "console.example.com", :user => "foo-production"}
      FakeWeb.register_uri(:get, api_url("apps/staging-foo/console"),
        :body => body.to_json)
      response = @client.console("staging-foo")
      response.should == {"port" => "40010", "host" => "console.example.com", "user"=>"foo-production"}
    end
  end

  describe "#send_invitation" do
    it "should send post with developer's email" do
      FakeWeb.register_uri(:post, api_url("apps/staging-foo/collaborations"), :body => {}.to_json)
      response = @client.send_invitation("staging-foo", "megan@example.com")
      response.should == {}
    end
  end

  describe "#delete_collaboration" do
    it "should send delete with developer's email in url" do
      FakeWeb.register_uri(:delete, api_url("apps/staging-foo/collaborations/megan@example.com"), :body => {}.to_json)
      @client.delete_collaboration("staging-foo", "megan@example.com")
    end
  end

  describe "#add_ssh_key" do
    it "should send put with give SSH key" do
      @client.should_receive(:post).with("/ssh_keys", {:ssh_key => "abc"})
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

  describe "#redeploy" do
    it "should send post to deploys resource for given cloud" do
      FakeWeb.register_uri(:post, api_url("apps/staging-foo/deploys"), :body => "")
      response = @client.redeploy("staging-foo")
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

    context "on 401 response" do
      it "should raise UnauthorizedException" do
        @response.stub(:code).and_return(401)
        @response.stub(:body).and_return("")
        @response.stub(:headers).and_return({})
        lambda {
          @client.post("/")
        }.should raise_error(Shelly::Client::UnauthorizedException)
      end
    end

    context "on 404 response" do
      it "should raise NotFoundException" do
        @response.stub(:code).and_return(404)
        @response.stub(:body).and_return("")
        @response.stub(:headers).and_return({})
        lambda {
          @client.post("/")
        }.should raise_error(Shelly::Client::NotFoundException)
      end
    end

    context "on 409 response" do
      it "should raise ConflictException" do
        @response.stub(:code).and_return(409)
        @response.stub(:body).and_return("")
        @response.stub(:headers).and_return({})
        lambda {
          @client.post("/")
        }.should raise_error(Shelly::Client::ConflictException)
      end
    end

    context "on 422 response" do
      it "should raise ValidationException" do
        @response.stub(:code).and_return(422)
        @response.stub(:body).and_return("")
        @response.stub(:headers).and_return({})
        lambda {
          @client.post("/")
        }.should raise_error(Shelly::Client::ValidationException)
      end
    end

    context "on unsupported response" do
      it "should raise generic APIException" do
        @response.stub(:code).and_return(500)
        @response.stub(:body).and_return("")
        @response.stub(:headers).and_return({:x_request_id => "id123"})
        lambda {
          @client.post("/")
        }.should raise_error { |error|
          error.should be_a(Shelly::Client::APIException)
          error.request_id.should == "id123"
        }
      end
    end

    it "should return empty hash if response is not a valid JSON" do
      JSON.should_receive(:parse).with("").and_raise(JSON::ParserError)
      @response.stub(:code).and_return("204")
      @response.stub(:body).and_return("")
      @response.stub(:headers).and_return({})
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
