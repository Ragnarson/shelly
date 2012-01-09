require 'erb'
require 'launchy'
require "shelly/backup"

module Shelly
  class App < Model
    DATABASE_KINDS = %w(postgresql mongodb redis none)

    attr_accessor :code_name, :databases, :ruby_version, :environment,
      :git_url, :domains, :web_server_ip, :mail_server_ip

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

    def deploy_logs
      shelly.deploy_logs(code_name)
    end

    def deploy_log(log)
      shelly.deploy_log(code_name, log)
    end

    def application_logs
      shelly.application_logs(code_name)
    end

    def database_backups
      shelly.database_backups(code_name).map do |attributes|
        Shelly::Backup.new(attributes.merge("code_name" => code_name))
      end
    end

    def database_backup(handler)
      attributes = shelly.database_backup(code_name, handler)
      Shelly::Backup.new(attributes.merge("code_name" => code_name))
    end

    def restore_backup(filename)
      shelly.restore_backup(code_name, filename)
    end

    def request_backup(kind)
      shelly.request_backup(code_name, kind)
    end

    def logs
      shelly.cloud_logs(code_name)
    end

    def start
      shelly.start_cloud(code_name)
    end

    def stop
      shelly.stop_cloud(code_name)
    end

    def redeploy
      shelly.redeploy(code_name)
    end

    def cloudfile_path
      File.join(Dir.pwd, "Cloudfile")
    end

    def self.guess_code_name
      File.basename(Dir.pwd)
    end

    def users
      shelly.app_users(code_name)
    end

    def configs
      @configs ||= shelly.app_configs(code_name)
    end

    def user_configs
      configs.find_all { |config| config["created_by_user"] }
    end

    def shelly_generated_configs
      configs.find_all { |config| config["created_by_user"] == false }
    end

    def config(path)
      shelly.app_config(code_name, path)
    end

    def create_config(path, content)
      shelly.app_create_config(code_name, path, content)
    end

    def update_config(path, content)
      shelly.app_update_config(code_name, path, content)
    end

    def delete_config(path)
      shelly.app_delete_config(code_name, path)
    end

    # returns result of execution of given code, or false when app was not
    # running
    def run(file_name_or_code)
      code = if File.exists?(file_name_or_code)
               File.read(file_name_or_code)
             else
               file_name_or_code
             end

      response = shelly.run(code_name, code)
      response["result"]
    end

    def attributes
      @attributes ||= shelly.app(code_name)
    end

    def web_server_ip
      attributes["web_server_ip"]
    end

    def mail_server_ip
      attributes["mail_server_ip"]
    end

    def open_billing_page
      url = "#{shelly.shellyapp_url}/login?api_key=#{current_user.token}&return_to=/apps/#{code_name}/edit_billing"
      Launchy.open(url)
    end

    def self.inside_git_repository?
      system("git status > /dev/null 2>&1")
    end

    def to_s
      code_name
    end
  end
end
