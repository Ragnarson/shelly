require "yaml"

module Shelly
  class Cloud < Model
    attr_accessor :code_name, :content

    def initialize(attributes = {})
      @code_name = attributes["code_name"]
      @content   = attributes["content"]
    end

    # Public: Return databases for given Cloud in Cloudfile
    # Returns Array of databases
    def databases
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

    # Public: Return databases to backup for given Cloud in Cloudfile
    # Returns Array of databases, except redis db
    def backup_databases
      databases - ['redis']
    end

    def to_s
      code_name
    end

    private

    # Internal: Checks if specified option is present
    def option?(option)
      content["servers"].any? {|_, settings| settings.has_key?(option)}
    end
  end
end
