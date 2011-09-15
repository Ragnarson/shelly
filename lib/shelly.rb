require "rubygems"
require "thor"
require "core_ext/object"
require "shelly/helpers"

module Shelly
  autoload :Client, "shelly/client"
  autoload :User, "shelly/user"
  autoload :VERSION, "shelly/version"
end
