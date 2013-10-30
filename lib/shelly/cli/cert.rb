require "shelly/cli/command"

module Shelly
  module CLI
    class Cert < Command
      namespace :cert
      include Helpers

      before_hook :logged_in?, :only => [:show, :create, :update]

      class_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"

      desc "show", "Show current certificate information"
      def show
        app = multiple_clouds(options[:cloud], "backup list")

        cert = app.cert
        say "Issuer: #{cert['info']['issuer']}"
        say "Subject: #{cert['info']['subject']}"
        say "Not valid before: #{Time.parse(cert['info']['since']).
          getlocal.strftime("%Y-%m-%d %H:%M:%S")}"
        say "Expires: #{Time.parse(cert['info']['to']).
          getlocal.strftime("%Y-%m-%d %H:%M:%S")}"
      rescue Client::NotFoundException => e
        raise unless e.resource == :certificate
        say_error "Certificate not found"
      end

      desc "create CERT_PATH [BUNDLE_PATH] KEY_PATH", "Add certificate to your cloud"
      long_desc %{
        Add certificate to your cloud.\n
        CERT_PATH - path to certificate.\n
        KEY_PATH - path to private key.\n
        BUNDLE_PATH - optional path to certificate bundle path.
      }
      def create(cert_path, key_path, bundle_path = nil)
        app = multiple_clouds(options[:cloud], "cert create CERT_PATH [BUNDLE_PATH] KEY_PATH")

        content = ::File.read(cert_path).strip
        bundle = bundle_path ? ::File.read(bundle_path).strip : ""
        key = ::File.read(key_path).strip

        content = content + "\n" + bundle
        cert = app.create_cert(content, key)

        say "Certificate was added to your cloud", :green
        if cert['ip_address']
          say "Deploying certificate on front end."
          say "Point your domain to private IP address: #{cert['ip_address']}"
        else
          say "SSL requires certificate and private IP address."
          say "Private IP address was requested for your cloud."
          say "Support has been notified and will contact you shortly."
        end
      rescue Client::ValidationException => e
        e.each_error { |error| say_error error, :with_exit => false }
        exit 1
      rescue Client::ConflictException => e
        say_error e[:message]
      end

      desc "update CERT_PATH [BUNDLE_PATH] key", "Update current certificate"
      long_desc %{
        Update current certificate.\n
        CERT_PATH - path to certificate.\n
        KEY_PATH - path to private key.\n
        BUNDLE_PATH - optional path to certificate bundle path.
      }
      def update(cert_path, key_path, bundle_path = nil)
        app = multiple_clouds(options[:cloud], "cert update CERT_PATH [BUNDLE_PATH] KEY_PATH")

        content = ::File.read(cert_path).strip
        bundle = bundle_path ? ::File.read(bundle_path).strip : ""
        key = ::File.read(key_path).strip

        content = content + "\n" + bundle
        cert = app.update_cert(content, key)

        say "Certificate was updated", :green
        if cert['ip_address']
          say "Deploying certificate on front end."
          say "Point your domain to private IP address: #{cert['ip_address']}"
        else
          say "SSL requires certificate and private IP address."
          say "Private IP address was requested for your cloud."
          say "Support has been notified and will contact you shortly."
        end
      rescue Client::ValidationException => e
        e.each_error { |error| say_error error, :with_exit => false }
        exit 1
      rescue Client::NotFoundException => e
        raise unless e.resource == :certificate
        say_error "Certificate not found"
      rescue Client::ConflictException => e
        say_error e[:message]
      end
    end
  end
end
