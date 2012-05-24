require "yaml"

module Shelly
  class Cloudfile < Model
    attr_accessor :content
    # Cloudfile attributes used for generating Cloudfile from a template
    attr_accessor :code_name, :ruby_version, :environment, :domains,
      :databases, :size

    # FIXME: use path here
    def self.present?
      File.exists?(File.join(Dir.pwd, "Cloudfile"))
    end

    def initialize
      open if File.exists?(path)
    end

    # Public: Path to Cloudfile in current directory
    # Returns path as String
    def path
      File.join(Dir.pwd, "Cloudfile")
    end

    def open
      @content = YAML.load(File.open(path))
    end

    def create
      File.open(path, "a+") { |f| f << generate }
    end

    # Internal: Return path to Cloudfile template
    def template_path
      File.join(File.dirname(__FILE__), "templates", "Cloudfile.erb")
    end

    # Public: Generate example Cloudfile based on object attributes
    # Returns the generated Cloudfile as String
    def generate
      @email = current_user.email
      @thin = (@size == "small" ? 2 : 4)
      template = File.read(template_path)
      cloudfile = ERB.new(template, 0, "%<>-")
      cloudfile.result(binding)
    end

    def clouds
      @content.keys.sort if @content
    end
  end
end
