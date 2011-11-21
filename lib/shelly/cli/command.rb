module Shelly
  module CLI
    class Command < Thor
      class_option :debug, :type => :boolean, :desc => "Show debug information"
    end
  end
end
