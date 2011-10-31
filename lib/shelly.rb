require "rubygems"
require "thor"
require "core_ext/object"
require "core_ext/array"
require "core_ext/hash"
require "shelly/helpers"
require "shelly/base"
require "thor/options"

module Shelly
  autoload :App, "shelly/app"
  autoload :Cloudfile, "shelly/cloudfile"
  autoload :Client, "shelly/client"
  autoload :User, "shelly/user"
  autoload :VERSION, "shelly/version"
end

