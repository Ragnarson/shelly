require 'erb'
require 'launchy'

module Shelly
  class App < Base
    DATABASE_KINDS = %w(postgresql mongodb redis none)
    attr_accessor :purpose, :code_name, :databases, :ruby_version, :environment, :git_url, :domains

    def initialize
      @ruby_version = "MRI-1.9.2"
      @environment = "production"
    end

    def add_git_remote
      system("git remote rm #{purpose} &> /dev/null")
      system("git remote add #{purpose} #{git_url}")
    end

    def generate_cloudfile
      @email = current_user.email
      @databases = databases
      @domains = domains.nil? ? ["#{code_name}.winniecloud.com"] : domains
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
        :environment  => environment,
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

    def users(apps)
      shelly.app_users(apps)
    end

    def open_billing_page
      url = "#{shelly.shellyapp_url}/login?api_key=#{current_user.token}&return_to=/apps/#{code_name}/edit_billing"
      Launchy.open(url)
    end

    def self.inside_git_repository?
      system("git status > /dev/null 2>&1")
    end
  end
end

