require "rubygems"
require "thor"
require "core_ext/object"
require "core_ext/array"
require "shelly/helpers"
require "shelly/base"

module Shelly
  autoload :App, "shelly/app"
  autoload :Client, "shelly/client"
  autoload :User, "shelly/user"
  autoload :VERSION, "shelly/version"
end
