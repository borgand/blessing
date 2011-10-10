require 'unicorn/launcher'

module Blessing

  # This class holds all handles to a specific Unicorn instance
  # and through this that Unicorn is manipulated
  class Runner
  
    attr_reader :config_file, :opts

    DEFAULT_OPTS={
      :unicorn => `which unicorn`,
    }

    def initialize conf, opts = {}
      @config_file = conf
      @opts = DEFAULT_OPTS.merge opts
      parse_configuration
    end

    # Let Unicorn parse it's config file
    def parse_configuration
      conf_str = File.read @config_file

      # Parse parameters we are interested in
      [:pid].each do |key|
        if conf_str =~/#{key} (.*)/
          @opts[key] = eval $1
        end
      end
    end


    # Starts the actual Unicorn! process
    def start
      fork do
        # Options to Unicorn! process
        options ={:config_file => @config_file}

        app = Unicorn.builder('config.ru',{})
        Unicorn::Launcher.daemonize!(options)
        Unicorn::HttpServer.new(app,options).start.join
      end
      Process.wait
    end

    # Stops the actual Unicorn! process
    def stop
      if File.exists? opts[:pid]
        # Lets not panic if the process is already dead
        begin
          Process.kill "QUIT", pid
        rescue => e
          # TODO: instead log this as unexpected
        end
      end
    end

    # Reload Unicorn! master process
    def reload
      begin
        Process.kill "HUP", pid
      rescue => e
        # TODO: log unexpected error
      end
    end

    private
    # Read PID from pid-file
    def pid
      File.read(opts[:pid]).chomp.to_i
    end

  end
end
