class Thor
  class Options < Arguments
    def check_unknown!
      # thor >= 0.15.0
      unknown = if defined? @extra
        # an unknown option starts with - or -- and has no more --'s afterward.
        @extra.select { |str| str =~ /^--?(?:(?!--).)*$/ }
      # thor < 0.15.0
      else
        @unknown
      end
      raise UnknownArgumentError, "shelly: unrecognized option '#{unknown.join(', ')}'\n" +
        "Usage: shelly [COMMAND]... [OPTIONS]\n" +
        "Try 'shelly --help' for more information" unless unknown.empty?
    end
  end
end
