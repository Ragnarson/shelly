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

    def gemfile_ruby_version?
      return false unless gemfile? && gemfile_lock?
      definition.ruby_version
    end

    def gemfile_ruby_version
      definition.ruby_version.version
    end

    # patchlevel is supported since bundler 1.4.0.rc
    def gemfile_ruby_patchlevel
      if definition.ruby_version.respond_to?(:patchlevel)
        definition.ruby_version.patchlevel
      end
    end

    def gemfile_engine
      definition.ruby_version.engine
    end

    def gemfile_engine_version
      definition.ruby_version.engine_version
    end

    def config_ru?
      repo_paths.include?("config.ru")
    end

    def rakefile?
      repo_paths.include?("Rakefile")
    end

    def gem?(name)
      gems.include?(name)
    end

    def task?(name)
      tasks.include?("rake #{name}")
    end

    # Public: Check all requirements that app has to fulfill
    def valid?
      gemfile? && gemfile_lock? && gem?("rake") &&
        (gem?("thin") || gem?("puma")) && config_ru? &&
        rakefile? && task?("db:migrate") && task?("db:setup")
    end

    def invalid?
      !valid?
    end

    # Public: Check if there are any warnings regarding app
    # structure, these warning don't prevent from deploying
    # to shelly
    def warnings?
      !gem?("shelly-dependencies") || gem?("shelly")
    end

    private

    def gems
      return [] unless gemfile? && gemfile_lock?
      @gems ||= definition.specs.map(&:name)
    end

    def definition
      @definition ||= Bundler::Definition.build(@gemfile_path,
        @gemfile_lock_path, nil)
    end

    def tasks
      return [] unless rakefile?
      @loaded_tasks ||= %x(rake -P).split("\n")
    end

    def repo_paths
      @repo_paths ||= begin
        files = `git ls-files`.split("\n")
        deleted_files = `git ls-files -d`.split("\n")
        files - deleted_files
      end
    end
  end
end
