module RSpec
  module Helpers
    def fake_stdin(strings)
      InputFaker.with_fake_input(strings) { yield }
    end

    def invoke(object, *args)
      object.class.send(:start, args.map { |arg| arg.to_s })
    end
  end
end
