require "yaml"

module Shelly
  class Cloudfile < Model
    attr_accessor :content
    # Cloudfile attributes used for generating Cloudfile from a template
    attr_accessor :code_name, :ruby_version, :environment, :domains,
      :databases, :size

    # Public: Return true if Cloudfile is present in current directory
    def present?
      File.exists?(path)
    end

    # Public: Clouds in Cloudfile
    # Returns Array of clouds names from Cloudfile
    # nil if there is no cloudfile
    def clouds
      content.keys.sort.map do |code_name|
        Shelly::Cloud.new("code_name" => code_name,
                          "content" => content[code_name.to_s])
      end if content
    end

    # Public: Generate example Cloudfile based on object attributes
    # Returns the generated Cloudfile as String
    def generate
      @email = current_user.email
      @thin = @size == "small" ? 2 : 4
      template = File.read(template_path)
      cloudfile = ERB.new(template, 0, "%<>-")
      cloudfile.result(binding)
    end

    # Public: Create Cloudfile in current path (or append if exists)
    # File is created based on assigned attributes
    def create
      File.open(path, "a+") { |f| f << generate }
    end

    # Internal: Load and parse Cloudfile
    def content
      return unless present?
      @content ||= YAML.load(File.open(path))
    end

    # Internal: Path to Cloudfile in current directory
    # Returns path as String
    def path
      File.join(Dir.pwd, "Cloudfile")
    end

    # Internal: Return path to Cloudfile template
    # Returns path as String
    def template_path
      File.join(File.dirname(__FILE__), "templates", "Cloudfile.erb")
    end
  end
end
