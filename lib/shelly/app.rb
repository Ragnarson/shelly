require 'erb'
require 'launchy'

module Shelly
  class App < Model
    DATABASE_KINDS = %w(postgresql mongodb redis none)
    attr_accessor :code_name, :databases, :ruby_version, :environment,
      :git_url, :domains

    def add_git_remote
      system("git remote rm production > /dev/null 2>&1")
      system("git remote add production #{git_url}")
    end

    def generate_cloudfile
      @email = current_user.email
      template = File.read(cloudfile_template_path)
      cloudfile = ERB.new(template, 0, "%<>-")
      cloudfile.result(binding)
    end

    def cloudfile_template_path
      File.join(File.dirname(__FILE__), "templates", "Cloudfile.erb")
    end

    def create
      attributes = {:name => code_name, :code_name => code_name, :domains => domains}
      response = shelly.create_app(attributes)
      self.git_url = response["git_url"]
      self.domains = response["domains"]
      self.ruby_version = response["ruby_version"]
      self.environment = response["environment"]
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

