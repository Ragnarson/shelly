require 'spec_helper'

describe Shelly::Hook do

  # class HookTest
  #   extend Shelly::Hook
  #   before_hook :hook, :only => [:run_one]
  #
  #   def self.dispatch(fake, fake2)
  #     @@order << :dispatch
  #   end
  #
  #   def hook
  #     @@order = []
  #     @@order << :hook
  #   end
  # end
  #
  # describe "#before_hook" do
  #   it "should exectude hook method before" do
  #     order = HookTest.send(:dispatch, nil, ["run_one"])
  #     order.should == [:hook, :dispatch]
  #   end
  # end
end