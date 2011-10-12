require 'erb'
require 'launchy'

module Shelly
  class App < Base
    DATABASE_KINDS = %w(postgresql mongodb redis none)
    attr_accessor :purpose, :code_name, :databases, :ruby_version, :environment, :git_url

    def initialize
      @ruby_version = "MRI-1.9.2"
    end

    def add_git_remote(force = false)
      system("git remote rm #{purpose}") if force
      system("git remote add #{purpose} #{git_url}")
    end

    def remote_exists?
      IO.popen("git remote").read.split("\n").include?(purpose)
    end

    def generate_cloudfile
      @email = current_user.email
      @databases = databases
      template = File.read(cloudfile_template_path)
      cloudfile = ERB.new(template, 0, "%<>-")
      cloudfile.result(binding)
    end

    def cloudfile_template_path
      File.join(File.dirname(__FILE__), "templates", "Cloudfile.erb")
    end

    def create
      attributes = {
        :name         => code_name,
        :code_name    => code_name,
        :environment  => purpose,
        :ruby_version => ruby_version,
        :domain_name  => "#{code_name}.shellycloud.com"
      }
      response = shelly.create_app(attributes)
      self.git_url = response["git_url"]
    end

    def create_cloudfile
      content = generate_cloudfile
      File.open(cloudfile_path, "a+") { |f| f << content }
    end

    def cloudfile_path
      File.join(Dir.pwd, "Cloudfile")
    end

    def self.guess_code_name
      File.basename(Dir.pwd)
    end

    def open_billing_page
      url = "#{shelly.api_url}/apps/#{code_name}/edit_billing?api_key=#{current_user.token}"
      Launchy.open(url)
    end

    def self.inside_git_repository?
      system("git status &> /dev/null")
    end
  end
end
