# encoding: utf-8

require "shelly/cli/command"

module Shelly
  module CLI
    class Endpoint < Command
      namespace :endpoint
      include Helpers

      before_hook :logged_in?, :only => [:index, :show, :create, :update]

      class_option :cloud, :type => :string, :aliases => "-c", :desc => "Specify cloud"

      desc "list", "List HTTP endpoints"
      def list
        app = multiple_clouds(options[:cloud], "endpoint list")

        endpoints = app.endpoints

        if endpoints.present?
          say "Available HTTP endpoints", :green
          say_new_line
          to_display = [["UUID", "|  IP address", "|  Certificate", "|  SNI"]]

          endpoints.each do |endpoint|

            to_display << [
              endpoint['uuid'],
              "|  #{print_check(endpoint['ip_address'], :return_value => true)}",
              "|  #{print_check(endpoint['info']['domain'], :return_value => true)}",
              "|  #{print_check(endpoint['sni'])}"
            ]
          end

          print_table(to_display, :ident => 2)
        else
          say "No HTTP endpoints available"
        end
      end

      desc "show UUID", "Show detail information about HTTP endpoint"
      def show(uuid)
        app = multiple_clouds(options[:cloud], "endpoint show UUID")
        endpoint = app.endpoint(uuid)

        say "UUID: #{endpoint['uuid']}"
        say "IP address: #{endpoint['ip_address']}", nil, true
        say "SNI: #{"✓" if endpoint['sni']}", nil, true

        say_new_line
        if endpoint['info']['subject'] && endpoint['info']['issuer']
          say "Certificate details:", :green
          say "Domain: #{endpoint['info']['domain']}", nil, true
          say "Issuer: #{endpoint['info']['issuer']}"
          say "Subject: #{endpoint['info']['subject']}"
          say "Not valid before: #{Time.parse(endpoint['info']['since']).
            getlocal.strftime("%Y-%m-%d %H:%M:%S")}"
          say "Expires: #{Time.parse(endpoint['info']['to']).
            getlocal.strftime("%Y-%m-%d %H:%M:%S")}"
        else
          say "No SSL certificate added"
        end
      rescue Client::NotFoundException => e
        raise unless e.resource == :endpoint
        say_error "Endpoint not found"
      end

      desc "create [CERT_PATH] [KEY_PATH] [BUNDLE_PATH]", "Add HTTP endpoint " \
        "to your cloud"
      long_desc %{
        Add HTTP endpoint to your cloud. Adding SSL certificate is optional and not required\n
        CERT_PATH - path to certificate.\n
        KEY_PATH - path to private key.\n
        BUNDLE_PATH - optional path to certificate bundle path.
      }
      method_option "sni", :type => :boolean,
        :desc => "Create SNI endpoint"
      def create(cert_path = nil, key_path = nil, bundle_path = nil)
        app = multiple_clouds(options[:cloud],
          "endpoint create [CERT_PATH] [KEY_PATH] [BUNDLE_PATH]")
        sni = options["sni"]

        say "Every unique IP address assigned to endpoint costs 10€/month"
        say "It's required for SSL/TLS"
        if cert_path == nil && key_path == nil
          say "You didn't provide certificate but it can be added later"
          say "Assigned IP address can be used to catch all domains pointing to that address, without SSL/TLS enabled"
          exit(0) unless yes?("Are you sure you want to create endpoint without certificate (yes/no):")
        elsif app.endpoints.count > 0
          ask_if_endpoints_were_already_created(app, sni)
        else
          exit(0) unless yes?("Are you sure you want to create endpoint? (yes/no):")
        end

        certificate, key = read_certificate_components(cert_path, key_path,
          bundle_path)

        endpoint = app.create_endpoint(certificate, key, sni)

        say "Endpoint was created for #{app} cloud", :green
        if endpoint['ip_address']
          say "Deployed certificate on front end servers." if certificate && key
          say "Point your domain to private IP address: #{endpoint['ip_address']}"
        else
          say "Private IP address was requested for your cloud."
          say "Support has been notified and will contact you shortly."
        end
      rescue Client::ConflictException => e
        say_error e['message']
      rescue Client::ValidationException => e
        e.each_error { |error| say_error error, :with_exit => false }
        exit 1
      end

      desc "update UUID CERT_PATH KEY_PATH [BUNDLE_PATH]", "Update HTTP "\
        "endpoint by adding SSL certificate"
      long_desc %{
        Update current HTTP endpoint with SSL certificate\n
        CERT_PATH - path to certificate.\n
        KEY_PATH - path to private key.\n
        BUNDLE_PATH - optional path to certificate bundle path.
      }
      def update(uuid, cert_path, key_path, bundle_path = nil)
        app = multiple_clouds(options[:cloud],
          "endpoint update UUID CERT_PATH KEY_PATH [BUNDLE_PATH]")

        certificate, key = read_certificate_components(cert_path, key_path,
          bundle_path)

        endpoint = app.update_endpoint(uuid, certificate, key)

        say "Endpoint was updated", :green
        if endpoint['ip_address']
          say "Deployed certificate on front end servers."
          say "Point your domain to private IP address: #{endpoint['ip_address']}"
        else
          say "Private IP address was requested for your cloud."
          say "Support has been notified and will contact you shortly."
        end
      rescue Client::ValidationException => e
        e.each_error { |error| say_error error, :with_exit => false }
        exit 1
      rescue Client::ConflictException => e
        say_error e['message']
      rescue Client::NotFoundException => e
        raise unless e.resource == :endpoint
        say_error "Endpoint not found"
      end

      desc "delete UUID", "Delete HTTP endpoint"
      def delete(uuid)
        app = multiple_clouds(options[:cloud], "endpoint delete UUID")
        endpoint = app.endpoint(uuid)

        if endpoint['ip_address']
          say_warning "Removing endpoint will release #{endpoint['ip_address']} IP address."
        end
        if yes?("Are you sure you want to delete endpoint (yes/no):")
          app.delete_endpoint(uuid)
          say "Endpoint was deleted"
        end
      rescue Client::NotFoundException => e
        raise unless e.resource == :endpoint
        say_error "Endpoint not found"
      end

      no_tasks do
        def print_check(check, options = {})
          return check if options[:return_value] && check
          check ? "✓" : "✗"
        end

        def read_certificate_components(cert_path, key_path, bundle_path)
          if cert_path || key_path
            say_error "Provide both certificate and key" unless (cert_path && key_path)

            certificate = ::File.read(cert_path).strip
            bundle = bundle_path ? ::File.read(bundle_path).strip : ""
            key = ::File.read(key_path).strip

            certificate = certificate + "\n" + bundle

            [certificate, key]
          end
        end

        def ask_if_endpoints_were_already_created(app, sni)
          cli = Shelly::CLI::Endpoint.new
          cli.options = {:cloud => app}
          cli.list
          say_new_line
          question = unless sni.nil?
            "You already have assigned endpoint(s). Are you sure you" \
            " want to create another one with SNI? (yes/no):"
          else
            "You already have assigned endpoint(s). Are you sure you" \
            " want to create another one with a new IP address? (yes/no):"
          end
          exit(0) unless yes?(question)
        end
      end
    end
  end
end
