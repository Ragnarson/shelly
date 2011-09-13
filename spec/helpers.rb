module RSpec
  module Helpers
    def fake_stdin(strings)
      InputFaker.with_fake_input(strings) { yield }
    end
  end
end
