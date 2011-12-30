require "rubygems"
require "core_ext/object"
require "core_ext/hash"

require "yaml"
if YAML.const_defined?(:ENGINE)
  YAML::ENGINE.yamler = 'syck'
end

require "shelly/helpers"
require "shelly/model"

module Shelly
  autoload :App, "shelly/app"
  autoload :Cloudfile, "shelly/cloudfile"
  autoload :Client, "shelly/client"
  autoload :User, "shelly/user"
  autoload :VERSION, "shelly/version"
end
