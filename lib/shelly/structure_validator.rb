require 'grit'
require 'bundler'

module Shelly
  class StructureValidator
    attr_reader :gemfile_path, :gemfile_lock_path

    def initialize(options = {})
      @gemfile_path = options[:gemfile] || "Gemfile"
      @gemfile_lock_path = options[:gemfile_lock] || "Gemfile.lock"
    end

    def gemfile_exists?
      File.exists?(@gemfile_path)
    end

    def config_ru_exists?
      repo = Grit::Repo.new(".")
      repo.status.map(&:path).include?("config.ru")
    end

    def gems
      return [] unless gemfile_exists?
      @d = Bundler::Definition.build(@gemfile_path, @gemfile_lock_path, nil)
      @gems = @d.specs.map(&:name)
    end
  end
end
