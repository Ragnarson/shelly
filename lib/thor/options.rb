class Thor
  class Options < Arguments
    def check_unknown!
      unknown = @extra.select { |str| str =~ /^--?(?:(?!--).)*$/ }
      raise UnknownArgumentError, "shelly: unrecognized option '#{@unknown.join(', ')}'\n" +
        "Usage: shelly [COMMAND]... [OPTIONS]\n" +
        "Try 'shelly --help' for more information" unless unknown.empty?
    end
  end
end
