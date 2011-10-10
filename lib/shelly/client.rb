require "rest_client"
require "json"

module Shelly
  class Client
    class APIError < Exception
      def initialize(response)
        @response = response
      end

      def message
        @response["message"]
      end

      def errors
        @response["errors"]
      end
    end

    def initialize(email = nil, password = nil)
      @email = email
      @password = password
    end

    def api_url
      ENV["SHELLY_URL"] || "https://admin.winniecloud.com/apiv2"
    end

    def register_user(email, password, ssh_key)
      post("/users", :user => {:email => email, :password => password, :ssh_key => ssh_key})
    end

    def token
      get("/token")
    end

    def create_app(attributes)
      post("/apps", :app => attributes)
    end

    def update_ssh_key(ssh_key)
      put("/ssh_keys", :ssh_key => ssh_key)
    end

    def post(path, params = {})
      request(path, :post, params)
    end

    def put(path, params = {})
      request(path, :put, params)
    end

    def get(path)
      request(path, :get)
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
      if [404, 422, 500].include?(response.code)
        # FIXME: move parsing JSON to APIError class
        error_details = JSON.parse(response.body)
        raise APIError.new(error_details)
      end

      response.return!
      JSON.parse(response.body)
    end
  end
end
