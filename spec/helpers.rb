module RSpec
  module Helpers
    def fake_stdin(strings)
      InputFaker.with_fake_input(strings) { yield }
    end

    def invoke(object, *args)
      object.class.send(:start, args.map { |arg| arg.to_s })
    end

    def green(string)
      "\e[32m#{string}\e[0m"
    end

    def red(string)
      "\e[31m#{string}\e[0m"
    end

    def hooks(model, method)
      model.class.hooks.inject([]) do |result, v|
        result << v[0] if v[1][:only].include?(method)
        result
      end
    end
  end
end
