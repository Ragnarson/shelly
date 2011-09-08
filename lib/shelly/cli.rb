require "shelly"

module Shelly
  class CLI < Thor
    map %w(-v --version) => :version
    desc "version", "Displays shelly version"
    def version
      say "shelly version #{Shelly::VERSION}"
    end
  end
end
