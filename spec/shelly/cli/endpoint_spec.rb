require "spec_helper"
require "shelly/cli/endpoint"

describe Shelly::CLI::Endpoint do
  before do
    FileUtils.stub(:chmod)
    @cli = Shelly::CLI::Endpoint.new
    Shelly::CLI::Endpoint.stub(:new).and_return(@cli)
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @client.stub(:authorize!)
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @app = Shelly::App.new("foo-production")
    Shelly::App.stub(:new).and_return(@app)
    File.open("Cloudfile", 'w') { |f| f.write("foo-production:\n") }
  end

  describe "#index" do
    it "should show all endpoints" do
      @app.should_receive(:endpoints).and_return(endpoints_response)

      $stdout.should_receive(:puts).with(green "Available HTTP endpoints")
      $stdout.should_receive(:puts).with("\n")
      $stdout.should_receive(:puts).with("  UUID   |  IP address  |  Certificate  |  SNI")
      $stdout.should_receive(:puts).with("  uuid1  |  10.0.0.1    |  example.com  |  \u2713")
      $stdout.should_receive(:puts).with("  uuid2  |  10.0.0.2    |  \u2717            |  \u2717")

      invoke(@cli, :list)
    end

    context "no endpoints" do
      it "should display information" do
        @app.should_receive(:endpoints).and_return([])
        $stdout.should_receive(:puts).with("No HTTP endpoints available")
        invoke(@cli, :list)
      end
    end
  end

  describe "#show" do
    it "should description" do
      @app.should_receive(:endpoint).with('uuid1').and_return(endpoint_response)
      $stdout.should_receive(:puts).with("UUID: uuid1")
      $stdout.should_receive(:puts).with("IP address: 10.0.0.1")
      $stdout.should_receive(:puts).with("SNI: \u2713")
      $stdout.should_receive(:puts).with("\n")
      $stdout.should_receive(:puts).with(green "Certificate details:")
      $stdout.should_receive(:puts).with("Domain: example.com")
      $stdout.should_receive(:puts).with("Issuer: CA")
      $stdout.should_receive(:puts).with("Subject: organization info")
      $stdout.should_receive(:puts).with("Not valid before:"\
        " #{Time.parse(endpoint_response['info']['since']).getlocal.strftime("%Y-%m-%d %H:%M:%S")}")
      $stdout.should_receive(:puts).with("Expires:"\
        " #{Time.parse(endpoint_response['info']['to']).getlocal.strftime("%Y-%m-%d %H:%M:%S")}")
      invoke(@cli, :show, 'uuid1')
    end

    context "endpoint not found" do
      it "should exit" do
        exception = Shelly::Client::NotFoundException.new("resource" => "endpoint")
        @app.should_receive(:endpoint).with('uuid').and_raise(exception)
        $stdout.should_receive(:puts).with(red "Endpoint not found")
        lambda {
          invoke(@cli, :show, 'uuid')
        }.should raise_error(SystemExit)
      end
    end
  end

  describe "#create" do
    before do
      File.stub(:read).with('crt_path').and_return('crt')
      File.stub(:read).with('key_path').and_return('key')
      File.stub(:read).with('bundle_path').and_return('bundle')
      @app.stub(:endpoints).and_return([])
    end

    context "with certificate" do
      it "should create endpoint with provided certificate" do
        @app.should_receive(:create_endpoint).with("crt\n", "key", nil).
          and_return(endpoint_response('ip_address' => '10.0.0.1'))

        $stdout.should_receive(:puts).with("Every unique IP address assigned to endpoint costs 10\u20AC/month")
        $stdout.should_receive(:puts).with("It's required for SSL/TLS")
        $stdout.should_receive(:print).with("Are you sure you want to create endpoint? (yes/no): ")

        $stdout.should_receive(:puts).with(green "Endpoint was created for #{@app.to_s} cloud")
        $stdout.should_receive(:puts).with("Deployed certificate on front end servers.")
        $stdout.should_receive(:puts).with("Point your domain to private IP address: 10.0.0.1")

        fake_stdin(["yes"]) do
          invoke(@cli, :create, "crt_path", "key_path")
        end
      end

      context "when sni option is true" do
        before do
          @app.stub_chain(:endpoints, :count).and_return(1)
          @cli.stub(:list)
        end

        it "should create endpoint with provided certificate" do
          @app.should_receive(:create_endpoint).with("crt\n", "key", true).
            and_return(endpoint_response('ip_address' => '10.0.0.1'))

          $stdout.should_receive(:puts).with("Every unique IP address assigned to endpoint costs 10\u20AC/month")
          $stdout.should_receive(:puts).with("It's required for SSL/TLS")
          $stdout.should_receive(:puts).with("\n")
          $stdout.should_receive(:print).with("You already have assigned" \
            " endpoint(s). Are you sure you want to create another one with" \
            " SNI? (yes/no): ")
          $stdout.should_receive(:puts).with(green "Endpoint was created for #{@app.to_s} cloud")
          $stdout.should_receive(:puts).with("Deployed certificate on front end servers.")
          $stdout.should_receive(:puts).with("Point your domain to private IP address: 10.0.0.1")

          @cli.options = {"sni" => true}
          fake_stdin(["yes"]) do
            invoke(@cli, :create, "crt_path", "key_path")
          end
        end
      end
    end

    context "without certificate" do
      it "should create endpoint" do
        @app.should_receive(:create_endpoint).with(nil, nil, true).
          and_return(endpoint_response('ip_address' => '10.0.0.1'))

        $stdout.should_receive(:puts).with("Every unique IP address assigned to endpoint costs 10\u20AC/month")
        $stdout.should_receive(:puts).with("It's required for SSL/TLS")
        $stdout.should_receive(:puts).with("You didn't provide certificate but it can be added later")
        $stdout.should_receive(:puts).with("Assigned IP address can be used to catch all domains pointing to that address, without SSL/TLS enabled")
        $stdout.should_receive(:print).with("Are you sure you want to create endpoint without certificate (yes/no): ")
        $stdout.should_receive(:puts).with(green "Endpoint was created for #{@app.to_s} cloud")
        $stdout.should_receive(:puts).with("Point your domain to private IP address: 10.0.0.1")

        @cli.options = {"sni" => true}
        fake_stdin(["yes"]) do
          invoke(@cli, :create)
        end
      end
    end

    context "multiple endpoints" do
      it "should create endpoint with provided certificate" do
        @app.should_receive(:create_endpoint).with("crt\n", "key", nil).
          and_return(endpoint_response('ip_address' => '10.0.0.1'))
        @app.stub(:endpoints).and_return(endpoints_response)

        $stdout.should_receive(:puts).with("Every unique IP address assigned to endpoint costs 10\u20AC/month")
        $stdout.should_receive(:puts).with("It's required for SSL/TLS")
        $stdout.should_receive(:puts).with(green "Available HTTP endpoints")
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:puts).with("  UUID   |  IP address  |  Certificate  |  SNI")
        $stdout.should_receive(:puts).with("  uuid1  |  10.0.0.1    |  example.com  |  \u2713")
        $stdout.should_receive(:puts).with("  uuid2  |  10.0.0.2    |  \u2717            |  \u2717")
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:print).with("You already have assigned endpoint(s). Are you sure you want to create another one with a new IP address? (yes/no): ")
        $stdout.should_receive(:puts).with(green "Endpoint was created for #{@app.to_s} cloud")
        $stdout.should_receive(:puts).with("Deployed certificate on front end servers.")
        $stdout.should_receive(:puts).with("Point your domain to private IP address: 10.0.0.1")

        fake_stdin(["yes"]) do
          invoke(@cli, :create, "crt_path", "key_path")
        end
      end
    end

    context "validation errors" do
      it "should show errors and exit" do
        exception = Shelly::Client::ValidationException.new({"errors" => [["key", "is invalid"]]})
        @app.should_receive(:create_endpoint).and_raise(exception)

        $stdout.should_receive(:puts).with("Every unique IP address assigned to endpoint costs 10\u20AC/month")
        $stdout.should_receive(:puts).with("It's required for SSL/TLS")
        $stdout.should_receive(:print).with("Are you sure you want to create endpoint? (yes/no): ")
        $stdout.should_receive(:puts).with(red "Key is invalid")

        lambda {
          fake_stdin(["yes"]) do
            invoke(@cli, :create, "crt_path", "key_path", "bundle_path")
          end
        }.should raise_error(SystemExit)
      end
    end

    context "providing one only part of certificate" do
      it "should show error and exit" do
        @app.should_not_receive(:create_endpoint)

        $stdout.should_receive(:puts).with("Every unique IP address assigned to endpoint costs 10\u20AC/month")
        $stdout.should_receive(:puts).with("It's required for SSL/TLS")
        $stdout.should_receive(:print).with("Are you sure you want to create endpoint? (yes/no): ")
        $stdout.should_receive(:puts).with(red "Provide both certificate and key")

        lambda {
          fake_stdin(["yes"]) do
            invoke(@cli, :create, "crt_path")
          end
        }.should raise_error(SystemExit)
      end
    end

    context "conflict error" do
      it "should show errors and exit" do
        exception = Shelly::Client::ConflictException.new("message" =>
          "That's an error")
        @app.should_receive(:create_endpoint).and_raise(exception)

        $stdout.should_receive(:puts).with("Every unique IP address assigned to endpoint costs 10\u20AC/month")
        $stdout.should_receive(:puts).with("It's required for SSL/TLS")
        $stdout.should_receive(:print).with("Are you sure you want to create endpoint? (yes/no): ")
        $stdout.should_receive(:puts).with(red "That's an error")

        lambda {
          fake_stdin(["yes"]) do
            invoke(@cli, :create, "crt_path", "key_path", "bundle_path")
          end
        }.should raise_error(SystemExit)
      end
    end
  end

  describe "#update" do
    before do
      File.stub(:read).with('crt_path').and_return('crt')
      File.stub(:read).with('key_path').and_return('key')
      File.stub(:read).with('bundle_path').and_return('bundle')
    end

    it "should create endpoint" do
      @app.should_receive(:update_endpoint).with('uuid', "crt\nbundle", "key").
        and_return(endpoint_response)
      $stdout.should_receive(:puts).with(green "Endpoint was updated")
      $stdout.should_receive(:puts).with("Deployed certificate on front end servers.")
      $stdout.should_receive(:puts).with("Point your domain to private IP address: 10.0.0.1")

      invoke(@cli, :update, 'uuid', "crt_path", "key_path", "bundle_path")
    end

    context "validation errors" do
      it "should show errors and exit" do
        exception = Shelly::Client::ValidationException.new({"errors" => [["key", "is invalid"]]})
        @app.should_receive(:update_endpoint).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Key is invalid")

        lambda {
          invoke(@cli, :update, 'uuid', "crt_path", "key_path", "bundle_path")
        }.should raise_error(SystemExit)
      end
    end

    context "conflict error" do
      it "should show errors and exit" do
        exception = Shelly::Client::ConflictException.new("message" =>
          "That's an error")
        @app.should_receive(:update_endpoint).and_raise(exception)
        $stdout.should_receive(:puts).with(red "That's an error")

        lambda {
          invoke(@cli, :update, "crt_path", "key_path", "bundle_path")
        }.should raise_error(SystemExit)
      end
    end
  end

  describe "#delete" do
    it "should ask to delete endpoint" do
      @app.should_receive(:endpoint).with('uuid').
        and_return(endpoint_response)
      @app.should_receive(:delete_endpoint).with('uuid')

      $stdout.should_receive(:puts).with(yellow "Removing endpoint will release 10.0.0.1 IP address.")
      $stdout.should_receive(:print).with("Are you sure you want to delete endpoint (yes/no): ")
      $stdout.should_receive(:puts).with("Endpoint was deleted")

      fake_stdin(["yes"]) do
        invoke(@cli, :delete, 'uuid')
      end

    end
  end

  def endpoints_response
    [
      { 'ip_address' => '10.0.0.1',
        'sni' => true,
        'uuid' => 'uuid1', 'info' => {
          'domain' => 'example.com',
          'issuer' => 'CA',
          'subjcet' => 'organization info',
          'since' => '2012-06-11 23:00:00 UTC',
          'to' => '2015-06-11 23:00:00 UTC'
        }
      },
      { 'ip_address' => '10.0.0.2',
        'sni' => false,
        'uuid' => 'uuid2', 'info' => {
          'domain' => nil,
          'issuer' => nil,
          'subjcet' => nil,
          'since' => nil,
          'to' => nil
         }
      }
    ]
  end

  def endpoint_response(options = {})
    {'ip_address' => '10.0.0.1', 'sni' => true,
     'uuid' => 'uuid1', 'info' => {
        'domain' => 'example.com',
        'issuer' => 'CA',
        'subject' => 'organization info',
        'since' => '2012-06-11 23:00:00 UTC',
        'to' => '2015-06-11 23:00:00 UTC'
      }
    }.merge(options)
  end
end
