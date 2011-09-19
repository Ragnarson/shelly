require "spec_helper"

describe Shelly::Client do
  before do
    ENV['SHELLY_URL'] = nil
    @client = Shelly::Client.new("bob@example.com", "secret")
    RestClient::Request.stub!(:execute)
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

  describe "#request_parameters" do
    it "should return hash of resquest parameters" do
      expected = {
        :method => :post,
        :url => "#{@client.api_url}/account",
        :headers => @client.headers,
        :payload => {:name => "bob"}.to_json,
        :username => "bob@example.com",
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

    context "on 302 response code" do
      it "should raise UnauthorizedException" do
        @response.stub(:code).and_return(302)
        lambda {
          @client.get("/account")
          }.should raise_error(Shelly::Client::UnauthorizedException)
      end
    end

    context "on 406 response code" do
      it "should raise UnauthorizedException" do
        exception = RestClient::RequestFailed.new
        exception.stub(:http_code).and_return(406)
        @response.should_receive(:return!).and_raise(exception)

        lambda {
          @client.get("/account")
        }.should raise_error(Shelly::Client::UnauthorizedException)
      end
    end

    %w(404 422 500).each do |code|
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

    context "on unsupported response code" do
      it "should raise UnsupportedResponseException exception" do
        exception = RestClient::RequestFailed.new
        exception.stub(:http_code).and_return(409)
        @response.should_receive(:return!).and_raise(exception)

        lambda {
          @client.get("/account")
        }.should raise_error(Shelly::Client::UnsupportedResponseException)
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
      @client.should_receive(:request).with("/account", :get)
      @client.get("/account")
    end
  end

  describe "#post" do
    it "should make POST request to given path with parameters" do
      @client.should_receive(:request).with("/account", :post, :name => "pink-one")
      @client.post("/account", :name => "pink-one")
    end
  end
end
