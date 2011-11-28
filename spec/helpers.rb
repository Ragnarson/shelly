module RSpec
  module Helpers
    def fake_stdin(strings)
      InputFaker.with_fake_input(strings) { yield }
    end

    def invoke(object, *args)
      object.send(:invoke, object.class, args.map)
    end
  end
end
