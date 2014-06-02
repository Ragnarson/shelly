require "spec_helper"
require "shelly/cli/command"

describe Shelly::CLI::Command do
  before { @command = Shelly::CLI::Command.new }

  context "when ENV['HOME'] is not set" do

    it 'should raise HomeNotSetError' do
      ENV.stub(:[]).with('HOME').and_return('')
      lambda {
        invoke(@command)
      }.should raise_error(Shelly::CLI::HomeNotSetError)
    end
  end
end

