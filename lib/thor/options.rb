class Thor
  class Options < Arguments

    def check_unknown!
      raise UnknownArgumentError, "shelly: unrecognized option '#{@unknown.join(', ')}'\n" +
        "Usage: shelly [COMMAND]... [OPTIONS]\n" +
        "Try 'shelly --help' for more information" unless @unknown.empty?
    end

  end
end

