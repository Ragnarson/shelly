require 'erb'
require 'launchy'

module Shelly
  class App < Model
    DATABASE_KINDS = %w(postgresql mongodb redis none)

    attr_accessor :code_name, :databases, :ruby_version, :environment,
      :git_url, :domains

    def initialize(code_name = nil)
      self.code_name = code_name
    end

    def add_git_remote
      system("git remote rm production > /dev/null 2>&1")
      system("git remote add production #{git_url}")
    end

    def remove_git_remote
      system("git remote rm production > /dev/null 2>&1")
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

    def delete
      shelly.delete_app(code_name)
    end

    def create_cloudfile
      content = generate_cloudfile
      File.open(cloudfile_path, "a+") { |f| f << content }
    end

    def database_backups
      shelly.database_backups(code_name)
    end

    def logs
      shelly.cloud_logs(self.code_name)
    end

    def start
      shelly.start_cloud(self.code_name)
    end

    def stop
      shelly.stop_cloud(self.code_name)
    end

    def cloudfile_path
      File.join(Dir.pwd, "Cloudfile")
    end

    def self.guess_code_name
      File.basename(Dir.pwd)
    end

    def ips
      shelly.app_ips(self.code_name)
    end

    def users
      shelly.app_users(self.code_name)
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

