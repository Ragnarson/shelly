require "rest_client"
require "json"
require "cgi"

module Shelly
  class Client
    class APIException < Exception
      attr_reader :status_code, :body

      def initialize(body = {}, status_code = nil)
        @status_code = status_code
        @body = body
      end

      def [](key)
        body[key.to_s]
      end
    end

    class UnauthorizedException < APIException; end
    class ConflictException < APIException; end
    class GemVersionException < APIException; end
    class ValidationException < APIException
      def errors
        self[:errors]
      end

      def each_error
        errors.each do |field, message|
          yield [field.gsub('_',' ').capitalize, message].join(" ")
        end
      end
    end
    class NotFoundException < APIException
      def resource
        self[:resource].to_sym
      end
    end

    attr_reader :email, :password

    def initialize(email = nil, password = nil)
      @email = email
      @password = password
    end

    def api_url
      ENV["SHELLY_URL"] || "https://api.shellycloud.com/apiv2"
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

    def app_configs(cloud)
      get("/apps/#{cloud}/configs")
    end

    def app_config(cloud, path)
      get("/apps/#{cloud}/configs/#{CGI.escape(path)}")
    end

    def app_create_config(cloud, path, content)
      post("/apps/#{cloud}/configs", :config => {:path => path, :content => content})
    end

    def app_update_config(cloud, path, content)
      put("/apps/#{cloud}/configs/#{CGI.escape(path)}", :config => {:content => content})
    end

    def app_delete_config(cloud, path)
      delete("/apps/#{cloud}/configs/#{CGI.escape(path)}")
    end

    def send_invitation(cloud, email)
      post("/apps/#{cloud}/collaborations", :email => email)
    end

    def delete_collaboration(cloud, email)
      delete("/apps/#{cloud}/collaborations/#{email}")
    end

    def create_app(attributes)
      post("/apps", :app => attributes)
    end

    def delete_app(code_name)
      delete("/apps/#{code_name}")
    end

    def add_ssh_key(ssh_key)
      post("/ssh_keys", :ssh_key => ssh_key)
    end

    def logout(ssh_key)
      delete("/ssh_keys", :ssh_key => ssh_key)
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

    def app(code_name)
      get("/apps/#{code_name}")
    end

    def command(cloud, body, type)
      post("/apps/#{cloud}/command", {:body => body, :type => type})
    end

    def deploy_logs(cloud)
      get("/apps/#{cloud}/deployment_logs")
    end

    def deploy_log(cloud, log)
      get("/apps/#{cloud}/deployment_logs/#{log}")
    end

    def application_logs(cloud)
      get("/apps/#{cloud}/application_logs")
    end

    def database_backups(code_name)
      get("/apps/#{code_name}/database_backups")
    end

    def database_backup(code_name, handler)
      get("/apps/#{code_name}/database_backups/#{handler}")
    end

    def restore_backup(code_name, filename)
      put("/apps/#{code_name}/database_backups/#{filename}/restore")
    end

    def request_backup(code_name, kind = nil)
      post("/apps/#{code_name}/database_backups", :kind => kind)
    end

    def collaborations(cloud)
      get("/apps/#{cloud}/collaborations")
    end

    def redeploy(cloud)
      post("/apps/#{cloud}/deploys")
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

    def delete(path, params = {})
      request(path, :delete, params)
    end

    def download_backup(cloud, filename, progress_callback = nil)
      File.open(filename, "w") do |out|
        process_response = lambda do |response|
          response.read_body do |chunk|
            out.write(chunk)
            progress_callback.call(chunk.size) if progress_callback
          end
        end

        options = request_parameters("/apps/#{cloud}/database_backups/#{filename}", :get)
        options = options.merge(:block_response => process_response,
          :headers => {:accept => "application/x-gzip"})

        RestClient::Request.execute(options)
      end
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
      body = JSON.parse(response.body) rescue JSON::ParserError && {}
      code = response.code
      if (400..599).include?(code)
        exception_class = case response.code
        when 401; UnauthorizedException
        when 404; NotFoundException
        when 409; ConflictException
        when 412; GemVersionException
        when 422; ValidationException
        else; APIException
        end
        raise exception_class.new(body, code)
      end
      response.return!
      body
    end
  end
end
