require "rubygems"
require "thor"
require "core_ext/object"

module Shelly
  autoload :Client, "shelly/client"
  autoload :User, "shelly/user"
  autoload :VERSION, "shelly/version"
end
