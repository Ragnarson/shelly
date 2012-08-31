class Thor
  class << self
    def before_hook(method, options = {})
      @hook = {} unless @hook
      @hook[method] = {:only => Array(options[:only])}
    end

    def hooks
      @hook
    end

    def send(*args)
      if args.first == :dispatch && !args[2].empty?
        running_task = args[2].first
        help = args[2].include?('--help') || args[2].include?('-h')
        @hook.each do |method, options|
          if options[:only].include?(running_task.to_sym) && !help
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
    rescue Errno::EPIPE
      # This happens if a thor task is piped to something like `head`,
      # which closes the pipe when it's done reading. This will also
      # mean that if the pipe is closed, further unnecessary
      # computation will not occur.
      exit(0)
    end

    # We overwrite this method so namespace is shown
    # shelly *backup* restore FILENAME
    def handle_argument_error(task, error, arity = nil)
      banner = self.banner(task, nil, self.to_s != 'Shelly::CLI::Main')
      raise InvocationError, "#{task.name.inspect} was called incorrectly. Call as `#{banner}`"
    end

    protected
    # this has to overwritten so that in tests args are passed correctly
    # only change is the commented line
    # its for some edge cases when boolean options are passed in some
    # strange order
    def dispatch(meth, given_args, given_opts, config) #:nodoc:
      meth ||= retrieve_task_name(given_args)
      task = all_tasks[normalize_task_name(meth)]

      if task
        args, opts = Thor::Options.split(given_args)
      else
        args, opts = given_args, nil
        task = Thor::DynamicTask.new(meth)
      end

      opts = given_opts || opts || []
      config.merge!(:current_task => task, :task_options => task.options)

      instance = new(args, opts, config)
      yield instance if block_given?
      # args = instance.args
      trailing = args[Range.new(arguments.size, -1)]

      instance.invoke_task(task, trailing || [])
    end
  end
end
