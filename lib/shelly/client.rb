require "rest_client"
require "json"
require "cgi"
require "netrc"

module Shelly
  class Client
    require 'shelly/client/errors'
    require 'shelly/client/shellyapp'
    require 'shelly/client/tunnels'
    require 'shelly/client/users'
    require 'shelly/client/apps'
    require 'shelly/client/configs'
    require 'shelly/client/deployment_logs'
    require 'shelly/client/application_logs'
    require 'shelly/client/database_backups'
    require 'shelly/client/deploys'
    require 'shelly/client/ssh_keys'
    require 'shelly/client/organizations'
    require 'shelly/client/auth'
    require 'shelly/client/cert'
    require 'shelly/client/maintenance'

    def api_url
      ENV["SHELLY_URL"] || "https://api.shellycloud.com/apiv2"
    end

    def api_host
      URI.parse(api_url).host
    end

    def query(options = {})
      "?" + options.map { |k, v|
        URI.escape(k.to_s) + "=" + URI.escape(v.to_s) }.join("&")
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

    def download_file(cloud, filename, url, progress_callback = nil)
      File.open(filename, "wb") do |out|
        process_response = lambda do |response|

          total_size = response.to_hash['file-size'].first.to_i if response.to_hash['file-size']
          response.read_body do |chunk|
            out.write(chunk)

            progress_callback.call(chunk.size,
              total_size) if progress_callback
          end
        end

        options = {
          :url            => url,
          :method         => :get,
          :block_response => process_response,
          :headers => {:accept => "application/x-gzip"}
        }.merge(http_basic_auth_options)

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
      if @email && @password
        {:user => @email, :password => @password}
      else
        basic_auth_from_netrc
      end
    end

    def request_parameters(path, method, params = {})
      parameters = {
        :method   => method,
        :url      => "#{api_url}#{path}",
        :headers  => headers
      }.merge(http_basic_auth_options)
      unless [:get, :head].include?(method)
        parameters = parameters.merge(:payload => params.to_json)
      end
      parameters
    end

    def process_response(response)
      body = JSON.parse(response.body) rescue JSON::ParserError && {}
      code = response.code
      if (400..599).include?(code)
        exception_class = case response.code
        when 401; UnauthorizedException
        when 403; ForbiddenException
        when 404; NotFoundException
        when 409; ConflictException
        when 412; GemVersionException
        when 422; ValidationException
        when 423; LockedException
        when 504; GatewayTimeoutException
        else; APIException
        end
        raise exception_class.new(body, code, response.headers[:x_request_id])
      end
      response.return!
      body
    end
  end
end
