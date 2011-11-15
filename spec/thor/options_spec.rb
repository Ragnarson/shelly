require 'spec_helper'
require 'thor/parser'

describe Thor::Options do
  def create(opts, defaults={})
    opts.each do |key, value|
      opts[key] = Thor::Option.parse(key, value) unless value.is_a?(Thor::Option)
    end
    @opt = Thor::Options.new(opts, defaults)
  end

  def parse(*args)
    @opt.parse(args.flatten)
  end

  describe "#parse" do
    describe "with :array type" do
      it "accepts a switch=<value> assignment, where value is a set of paramters split by comma or spaces" do
        create "--attributes" => :array
        parse("--attributes=a,b", "c, d", "e ,  f")["attributes"].should == ["a", "b", "c", "d", "e", "f"]
      end
    end
  end
end
