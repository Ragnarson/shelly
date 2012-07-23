require 'grit'
require 'bundler'

module Shelly
  class StructureValidator
    def initialize
      @gemfile_path = "Gemfile"
      @gemfile_lock_path = "Gemfile.lock"
    end

    def gemfile?
      repo_paths.include?(@gemfile_path)
    end

    def gemfile_lock?
      repo_paths.include?(@gemfile_lock_path)
    end

    def config_ru?
      repo_paths.include?("config.ru")
    end

    def gem?(name)
      gems.include?(name)
    end

    # Public: Check all requirements that app has to fulfill
    def valid?
      gemfile? && gemfile_lock? && gem?("thin") &&
        gem?("rake") && config_ru?
    end

    def invalid?
      !valid?
    end

    # Public: Check if there are any warnings regarding app
    # structure, these warning don't prevent from deploying
    # to shelly
    def warnings?
      !gem?("shelly-dependencies")
    end

    private

    def gems
      return [] unless gemfile? && gemfile_lock?
      definition = Bundler::Definition.build(@gemfile_path,
        @gemfile_lock_path, nil)
      @gems ||= definition.specs.map(&:name)
    end

    def repo_paths
      @repo_paths ||= begin
        repo = Grit::Repo.new(".")
        # Select files from repo which are unchanged, added or modified
        # and then return their paths
        repo.status.files.map(&:last).select { |status|
          status.type.nil? || status.type == 'A' || status.type == 'M'
        }.map(&:path)
      end
    end
  end
end
