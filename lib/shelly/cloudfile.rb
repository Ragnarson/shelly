require "yaml"

module Shelly
  class Cloudfile < Model
    attr_accessor :content
    # Cloudfile attributes used for generating Cloudfile from a template
    attr_accessor :code_name, :ruby_version, :environment, :domains,
      :databases, :size, :thin, :puma

    # Public: Return true if Cloudfile is present in current directory
    def present?
      File.exists?(path)
    end

    # Public: Clouds in Cloudfile
    # Returns Array of clouds names from Cloudfile
    # nil if there is no cloudfile
    def clouds
      content.keys.sort.map do |code_name|
        Shelly::App.new(code_name)
      end if content
    end

    # Public: Generate example Cloudfile based on object attributes
    # Returns the generated Cloudfile as String
    def generate
      @email = current_user.email
      template = File.read(template_path)
      cloudfile = ERB.new(template, nil, "%<>-")
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
    rescue Psych::SyntaxError => e
      # Using $stdout.puts so that it can be stubbed out on jruby.
      $stdout.puts "Your Cloudfile has invalid YAML syntax."
      $stdout.puts "You are seeing this message because we stopped supporting invalid YAML that was allowed in Ruby 1.8."
      $stdout.puts ""
      $stdout.puts "The most likely reason is a string starting with '*' in the domains array. The solution is to surround such strings with quotes, e.g.:"
      $stdout.puts "domains:"
      $stdout.puts "  - \"*.example.com\""
      $stdout.puts ""
      $stdout.puts "The original YAML error message was:"
      $stdout.puts "  #{e.message}"
      $stdout.puts ""
      $stdout.puts "If you need any assistance, feel free to contact support@shellycloud.com"
      exit 1
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
