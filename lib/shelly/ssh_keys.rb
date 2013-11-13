require "shelly/ssh_key"

module Shelly
  class SshKeys
    def initialize
      @rsa = SshKey.new('~/.ssh/id_rsa.pub')
      @dsa = SshKey.new('~/.ssh/id_dsa.pub')
    end

    def destroy
      [@rsa, @dsa].map(&:destroy).any?
    end

    def prefered_key
      @dsa.exists? ? @dsa : @rsa
    end
  end
end
