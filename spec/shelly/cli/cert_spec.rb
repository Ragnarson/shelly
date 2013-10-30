require "spec_helper"
require "shelly/cli/cert"

describe Shelly::CLI::Cert do
  before do
    FileUtils.stub(:chmod)
    @cli = Shelly::CLI::Cert.new
    Shelly::CLI::Cert.stub(:new).and_return(@cli)
    @client = mock
    Shelly::Client.stub(:new).and_return(@client)
    @client.stub(:authorize!)
    FileUtils.mkdir_p("/projects/foo")
    Dir.chdir("/projects/foo")
    @app = Shelly::App.new("foo-production")
    Shelly::App.stub(:new).and_return(@app)
    File.open("Cloudfile", 'w') { |f| f.write("foo-production:\n") }
  end

  describe "#show" do
    it "should description" do
      @app.should_receive(:cert).and_return(cert_response)
      $stdout.should_receive(:puts).with("Issuer: Some issuer")
      $stdout.should_receive(:puts).with("Subject: Some subject")
      $stdout.should_receive(:puts).with("Not valid before:"\
        " #{Time.parse(cert_response['info']['since']).getlocal.strftime("%Y-%m-%d %H:%M:%S")}")
      $stdout.should_receive(:puts).with("Expires:"\
        " #{Time.parse(cert_response['info']['to']).getlocal.strftime("%Y-%m-%d %H:%M:%S")}")
      invoke(@cli, :show)
    end

    context "certificate not found" do
      it "should exit" do
        exception = Shelly::Client::NotFoundException.new("resource" => "certificate")
        @app.should_receive(:cert).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Certificate not found")
        lambda {
          invoke(@cli, :show)
        }.should raise_error(SystemExit)
      end
    end
  end

  describe "#create" do
    before do
      File.stub(:read).with('crt_path').and_return('crt')
      File.stub(:read).with('key_path').and_return('key')
      File.stub(:read).with('bundle_path').and_return('bundle')
    end

    it "should create certificate" do
      @app.should_receive(:create_cert).with("crt\nbundle", "key").
        and_return(cert_response)
      $stdout.should_receive(:puts).with(green "Certificate was added to your cloud")
      $stdout.should_receive(:puts).with("Deploying certificate on front end.")
      $stdout.should_receive(:puts).with("Point your domain to private IP address: 10.0.0.1")

      invoke(@cli, :create, "crt_path", "key_path", "bundle_path")
    end

    it "should create certificate without bundle" do
      @app.should_receive(:create_cert).with("crt\n", "key").
        and_return(cert_response('ip_address' => nil))

      $stdout.should_receive(:puts).with(green "Certificate was added to your cloud")
      $stdout.should_receive(:puts).with("SSL requires certificate and private IP address.")
      $stdout.should_receive(:puts).with("Private IP address was requested for your cloud.")
      $stdout.should_receive(:puts).with("Support has been notified and will contact you shortly.")

      invoke(@cli, :create, "crt_path", "key_path")
    end

    context "validation errors" do
      it "should show errors and exit" do
        exception = Shelly::Client::ValidationException.new({"errors" => [["key", "is invalid"]]})
        @app.should_receive(:create_cert).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Key is invalid")

        lambda {
          invoke(@cli, :create, "crt_path", "key_path", "bundle_path")
        }.should raise_error(SystemExit)
      end
    end

    context "deployment conflict" do
      it "should show errors and exit" do
        exception = Shelly::Client::ConflictException.new({"message" => "Deployment is in progress"})
        @app.should_receive(:create_cert).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Deployment is in progress")

        lambda {
          invoke(@cli, :create, "crt_path", "key_path", "bundle_path")
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

    it "should create certificate" do
      @app.should_receive(:update_cert).with("crt\nbundle", "key").
        and_return(cert_response)
      $stdout.should_receive(:puts).with(green "Certificate was updated")
      $stdout.should_receive(:puts).with("Deploying certificate on front end.")
      $stdout.should_receive(:puts).with("Point your domain to private IP address: 10.0.0.1")

      invoke(@cli, :update, "crt_path", "key_path", "bundle_path")
    end

    it "should create certificate without bundle" do
      @app.should_receive(:update_cert).with("crt\n", "key").
        and_return(cert_response('ip_address' => nil))

      $stdout.should_receive(:puts).with(green "Certificate was updated")
      $stdout.should_receive(:puts).with("SSL requires certificate and private IP address.")
      $stdout.should_receive(:puts).with("Private IP address was requested for your cloud.")
      $stdout.should_receive(:puts).with("Support has been notified and will contact you shortly.")

      invoke(@cli, :update, "crt_path", "key_path")
    end

    context "validation errors" do
      it "should show errors and exit" do
        exception = Shelly::Client::ValidationException.new({"errors" => [["key", "is invalid"]]})
        @app.should_receive(:update_cert).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Key is invalid")

        lambda {
          invoke(@cli, :update, "crt_path", "key_path", "bundle_path")
        }.should raise_error(SystemExit)
      end
    end

    context "deployment conflict" do
      it "should show errors and exit" do
        exception = Shelly::Client::ConflictException.new({"message" => "Deployment is in progress"})
        @app.should_receive(:update_cert).and_raise(exception)
        $stdout.should_receive(:puts).with(red "Deployment is in progress")

        lambda {
          invoke(@cli, :update, "crt_path", "key_path", "bundle_path")
        }.should raise_error(SystemExit)
      end
    end
  end

  def cert_response(options = {})
    {
      'info' => {
        'issuer' => 'Some issuer',
        'subject' => 'Some subject',
        'since' =>  '2012-06-11 23:00:00 UTC',
        'to' => '2013-06-11 11:00:00 UTC'},
      'ip_address' => '10.0.0.1'
    }.merge(options)
  end
end
