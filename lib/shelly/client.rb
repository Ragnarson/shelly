require "rest_client"
require "json"

module Shelly
  class Client
    class APIError < Exception
      def initialize(response_body)
        @response = JSON.parse(response_body)
      end

      def message
        @response["message"]
      end

      def errors
        @response["errors"]
      end

      def url
        @response["url"]
      end

      def validation?
        message == "Validation Failed"
      end

      def unauthorized?
        message == "Unauthorized" || message =~ /Cloud .+ not found/
      end

      def each_error
        @response["errors"].each do |index,message|
          yield index.gsub('_',' ').capitalize + " " + message
        end
      end
    end

    def initialize(email = nil, password = nil)
      @email = email
      @password = password
    end

    def api_url
      ENV["SHELLY_URL"] || "https://admin.winniecloud.com/apiv2"
    end

    def shellyapp_url
      get("/shellyapp")["url"]
    end

    def register_user(email, password, ssh_key)
      post("/users", :user => {:email => email, :password => password, :ssh_key => ssh_key})
    end

    def token
      get("/token")
    end

    def send_invitation(cloud, email)
      post("/apps/#{cloud}/collaborations", :email => email)
    end

    def create_app(attributes)
      post("/apps", :app => attributes)
    end

    def add_ssh_key(ssh_key)
      post("/ssh_key", :ssh_key => ssh_key)
    end

    def start_cloud(cloud)
      put("/apps/#{cloud}/start")
    end

    def stop_cloud(cloud)
      put("/apps/#{cloud}/stop")
    end

    def apps
      get("/apps")
    end

    def ssh_key_available?(ssh_key)
    	get("/users/new", :ssh_key => ssh_key)
    end

    def app_users(cloud)
      get("/apps/#{cloud}/users")
    end

    def app_ips(cloud)
      get("/apps/#{cloud}/ips")
    end

    def post(path, params = {})
      request(path, :post, params)
    end

    def put(path, params = {})
      request(path, :put, params)
    end

    def get(path, params = {})
      request(path, :get, params)
    end

    def request(path, method, params = {})
      options = request_parameters(path, method, params)
      RestClient::Request.execute(options) do |response, request|
        process_response(response)
      end
    end

    def headers
      {:accept          => :json,
       :content_type    => :json,
       "shelly-version" => Shelly::VERSION}
    end

    def http_basic_auth_options
      @email ? {:user => @email, :password => @password} : {}
    end

    def request_parameters(path, method, params = {})
      {:method   => method,
       :url      => "#{api_url}#{path}",
       :headers  => headers,
       :payload  => params.to_json
      }.merge(http_basic_auth_options)
    end

    def process_response(response)
      if [401, 404, 422, 500].include?(response.code)
        raise APIError.new(response.body)
      end

      response.return!
      JSON.parse(response.body)
    end
  end
end

