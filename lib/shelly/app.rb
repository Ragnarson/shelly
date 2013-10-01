require 'erb'
require 'launchy'
require 'shelly/backup'

module Shelly
  class App < Model
    DATABASE_KINDS = %w(postgresql mongodb redis)
    DATABASE_CHOICES = DATABASE_KINDS + %w(none)
    SERVER_SIZES = %w(small large)

    attr_accessor :code_name, :databases, :ruby_version, :environment,
      :git_url, :domains, :web_server_ip, :size, :thin, :content,
      :organization_name, :zone_name

    def initialize(code_name = nil, content = nil)
      self.code_name = code_name
      self.content = content
    end

    def self.from_attributes(attributes)
      new(attributes["code_name"]).tap do |app|
        app.attributes = attributes
      end
    end

    def attributes=(attributes)
      @attributes = attributes
    end

    def thin
      size == "small" ? 2 : 4
    end

    def puma
      size == "small" ? 1 : 2
    end

    def databases=(dbs)
      @databases = dbs - ['none']
    end

    def add_git_remote(remote_name = 'shelly')
      system("git remote rm #{remote_name} > /dev/null 2>&1")
      system("git remote add #{remote_name} #{git_url}")
    end

    def git_remote_exist?(remote_name = 'shelly')
      IO.popen("git remote").read.include?(remote_name)
    end

    def git_fetch_remote(remote = 'shelly')
      system("git fetch #{remote} > /dev/null 2>&1")
    end

    def remove_git_remote
      remote = git_remote_name
      if remote.present?
        system("git remote rm #{remote} > /dev/null 2>&1")
      end
    end

    def git_remote_name
      io = IO.popen("git remote -v").readlines
      remote = io.select {|line| line.include? git_info["repository_url"]}.first
      remote.split("\t").first unless remote.nil?
    end

    def create
      attributes = {:code_name => code_name,
                    :organization_name => organization_name,
                    :zone_name => zone_name}
      response = shelly.create_app(attributes)
      assign_attributes(response)
    end

    def create_cloudfile
      cloudfile = Cloudfile.new
      cloudfile.code_name = code_name
      cloudfile.ruby_version = ruby_version
      cloudfile.environment = environment
      cloudfile.domains = domains
      cloudfile.size = size
      if ruby_version == 'jruby'
        cloudfile.puma = puma
      else
        cloudfile.thin = thin
      end
      cloudfile.databases = databases
      cloudfile.create
    end

    def delete
      shelly.delete_app(code_name)
    end

    def deploy_logs
      shelly.deploy_logs(code_name)
    end

    def deploy_log(log)
      shelly.deploy_log(code_name, log)
    end

    def application_logs(options = {})
      shelly.application_logs(code_name, options)
    end

    def application_logs_tail
      shelly.application_logs_tail(code_name) { |l| yield(l) }
    end

    def download_application_logs_attributes(date)
      shelly.download_application_logs_attributes(code_name, date)
    end

    def download_application_logs(options, callback)
      shelly.download_file(code_name, options["filename"], options["url"], callback)
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

    def import_database(kind, filename, server)
      ssh_with_db_server(:command => "import_database #{kind.downcase} #{filename}",
        :server => server)
    end

    def reset_database(kind)
      ssh_with_db_server(:command => "reset_database #{kind.downcase}")
    end

    def request_backup(kinds)
      Array(kinds).each do |kind|
        shelly.request_backup(code_name, kind)
      end
    end

    def logs
      shelly.cloud_logs(code_name)
    end

    def start
      shelly.start_cloud(code_name)["deployment"]["id"]
    end

    def stop
      shelly.stop_cloud(code_name)["deployment"]["id"]
    end

    # returns the id of created deployment
    def redeploy
      shelly.redeploy(code_name)["deployment"]["id"]
    end

    def deployment(deployment_id)
      shelly.deployment(code_name, deployment_id)
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

    def config_exists?(path)
      configs.any? { |config| config["path"] == path }
    end

    def rake(task)
      ssh(:command => "rake_runner \"#{task}\"")
    end

    def dbconsole
      ssh_with_db_server(:command => "dbconsole")
    end

    def mongoconsole
      ssh_with_db_server(:command => "mongo")
    end

    def redis_cli
      ssh_with_db_server(:command => "redis-cli")
    end

    def attributes
      @attributes ||= shelly.app(code_name)
    end

    def statistics
      @stats ||= shelly.statistics(code_name)
    end

    def web_server_ip
      attributes["web_server_ip"]
    end

    def git_info
      attributes["git_info"]
    end

    def state
      attributes["state"]
    end

    def maintenance?
      attributes["maintenance"]
    end

    def state_description
      attributes["state_description"]
    end

    def credit
      attributes["organization"]["credit"].to_f
    end

    def organization_details_present?
      attributes["organization"]["details_present"]
    end

    def self.inside_git_repository?
      system("git status > /dev/null 2>&1")
    end

    def turned_off?
      state == 'turned_off'
    end

    def in_deploy_failed_state?
      state == "deploy_failed"
    end

    def to_s
      code_name
    end

    def edit_billing_url
      "#{shelly.shellyapp_url}/organizations/#{organization_name || attributes['organization']['name']}/edit"
    end

    def open
      Launchy.open("http://#{attributes["domain"]}")
    end

    def console(server = nil)
      ssh(:server => server)
    end

    def list_files(path)
      ssh(:command => "ls -l #{persistent_disk}/#{path}")
    end

    def upload(source)
      tunnel_connection.tap do |conn|
        rsync(source, "#{conn['host']}:#{persistent_disk}", conn)
      end
    end

    def upload_database(source)
      configured_db_server_connection.tap do |conn|
        rsync(source, "#{conn['host']}:#{persistent_disk}", conn)
      end
    end

    def download(relative_source, destination)
      tunnel_connection.tap do |conn|
        source = File.join("#{conn['host']}:#{persistent_disk}", relative_source)
        rsync(source, destination, conn)
      end
    end

    def delete_file(remote_path)
      ssh(:command => "delete_file #{remote_path}")
    end

    def setup_tunnel(conn, local_port)
      system "ssh #{ssh_options(conn)} -N -L #{local_port}:localhost:#{conn['service']['port']} #{conn['host']}"
    end

    # Public: Return databases for given Cloud in Cloudfile
    # Returns Array of databases
    def cloud_databases
      content["servers"].map do |server, settings|
        settings["databases"]
      end.flatten.uniq
    end

    # Public: Delayed job enabled?
    # Returns true if delayed job is present
    def delayed_job?
      option?("delayed_job")
    end

    # Public: Whenever enabled?
    # Returns true if whenever is present
    def whenever?
      option?("whenever")
    end

    # Public: Sidekiq enabled?
    # Returns true if sidekiq is present
    def sidekiq?
      option?("sidekiq")
    end

    # Public: Thin app servers present?
    # Returns true if thin is present
    def thin?
      option?("thin")
    end

    # Public: Puma app servers present?
    # Returns true if puma is present
    def puma?
      option?("puma")
    end

    # Public: Return databases to backup for given Cloud in Cloudfile
    # Returns Array of databases, except redis db
    def backup_databases
      cloud_databases - ['redis']
    end

    # Public: Return true when app has been deployed
    # false otherwise
    def deployed?
      git_info["deployed_commit_sha"].present?
    end

    # Public: Return list of not deployed commits
    # Returns: A list of commits as a String with new line chars
    # format: "#{short SHA} #{commit message} (#{time, ago notation})"
    def pending_commits
      current_commit = IO.popen("git rev-parse 'HEAD'").read.strip
      format = "%C(yellow)%h%Creset %s %C(red)(%cr)%Creset"
      range = "#{git_info["deployed_commit_sha"]}..#{current_commit}"
      IO.popen(%Q{git log --no-merges --oneline --pretty=format:"#{format}" #{range}}).read.strip
    end

    # Returns first at least configured virtual server
    def tunnel_connection(service = "ssh", server = nil)
      shelly.tunnel(code_name, service, server)
    end

    private

    def assign_attributes(response)
      self.git_url = response["git_url"]
      self.domains = response["domains"]
      self.ruby_version = jruby? ? 'jruby' : response["ruby_version"]
      self.environment = response["environment"]
    end

    def persistent_disk
      "/home/#{code_name}/disk"
    end

    def jruby?
      RUBY_PLATFORM == 'java'
    end

    # Internal: Checks if specified option is present in Cloudfile
    def option?(option)
      content["servers"].any? {|_, settings| settings.has_key?(option)}
    end

    # Returns first at least configured virtual server if databases are configured
    def configured_db_server_connection(server = nil)
      shelly.configured_db_server(code_name, server)
    end

    def ssh(options = {})
      conn = tunnel_connection("ssh", options[:server])
      system "ssh #{ssh_options(conn)} -t #{conn['host']} #{options[:command]}"
    end

    def ssh_with_db_server(options = {})
      conn = configured_db_server_connection(options[:server])
      system "ssh #{ssh_options(conn)} -t #{conn['host']} #{options[:command]}"
    end

    def ssh_options(conn)
      "-o StrictHostKeyChecking=no -p #{conn['port']} -l #{conn['user']}"
    end

    def rsync(source, destination, conn)
      system "rsync -avz -e 'ssh #{ssh_options(conn)}' --progress #{source} #{destination}"
    end
  end
end
