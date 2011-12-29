class Thor
  class << self
    def before_hook(method, options = {})
      @hook = {} unless @hook
      @hook[method] = options
    end

    def send(*args)
      if args.first == :dispatch
        running_task = args[2].first
        @hook.each do |method, options|
          if options[:only].include?(running_task.to_sym)
            new.send(method)
          end
        end
      end
      super
    end

    def start(given_args=ARGV, config={})
      config[:shell] ||= Thor::Base.shell.new
      send(:dispatch, nil, given_args.dup, nil, config)
    rescue Thor::Error => e
      ENV["THOR_DEBUG"] == "1" ? (raise e) : config[:shell].error(e.message)
      exit(1) if exit_on_failure?
    end
  end
end
