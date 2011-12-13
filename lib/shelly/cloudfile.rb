require "yaml"

module Shelly
  class Cloudfile < Model
    attr_accessor :content

    def self.present?
      File.exists?(File.join(Dir.pwd, "Cloudfile"))
    end

    def initialize
      open if File.exists?(path)
    end

    def path
      File.join(Dir.pwd, "Cloudfile")
    end

    def open
      @content = YAML.load(File.open(path))
    end

    def write(hash)
      @content = hash
      File.open(path, "w") do |f|
        f.write(yaml(hash))
      end
    end

    def clouds
      @content.keys.sort
    end

    def yaml(hash)
      string = hash.deep_stringify_keys.to_yaml
      # FIXME: check if it possible to remove sub("---", "") by passing options to_yaml
      string.sub("---","").split("\n").map(&:rstrip).join("\n").strip
    end
  end
end
