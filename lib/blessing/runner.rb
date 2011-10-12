require 'unicorn/launcher'

module Blessing

  # This class holds all handles to a specific Unicorn instance
  # and through this that Unicorn is manipulated
  class Runner
  
    attr_reader :config_file, :opts

    DEFAULT_OPTS={
      :unicorn => `which unicorn`,  # Where is unicorn binary
      :max_restarts => 5,           # How many times to retry restarting
      :retry_delay => 1,            # How long (secs) sleep between retries
    }

    def initialize conf, opts = {}
      @config_file = conf
      @opts = DEFAULT_OPTS.merge opts
      parse_configuration
    end

    # Gets the modification time of the configuration file
    def config_modification_time
      File.stat(@config_file).ctime
    end

    # Let Unicorn parse it's config file
    def parse_configuration
      @config_timestamp = config_modification_time
      conf_str = File.read @config_file

      # Parse parameters we are interested in
      [:pid].each do |key|
        if conf_str =~/#{key} (.*)/
          @opts[key] = eval $1
        end
      end
    end

    # Detect if the configuration has been modified
    def config_modified?
      @config_timestamp != config_modification_time
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

    # Reload Unicorn if needed
    # Ensure it did start up
    # (This is the main cycle of Leader control)
    def check_reload
      # If configuration has changed, reload Unicorn
      if config_modified?
        reload
      end

      # In any case ensure it is running
      ensure_running

    end

    # Reload Unicorn! master process
    def reload
      begin
        Process.kill "HUP", pid
      rescue => e
        # TODO: log unexpected error
      end
    end

    # Verify the Unicorn! process is running
    def running?
      begin
        Process.kill 0, pid
        true
      rescue Errno::ESRCH
        # just verifying; logging should be done elsewhere
        false
      end
    end

    # Ensure the Unicorn! process is running
    # restarting it if needed
    def ensure_running
      unless success = running?
        opts[:max_restarts].times do
          start
          sleep opts[:retry_delay]
          break if success = running?
        end
      end
      success
    end

    private
    # Read PID from pid-file
    def pid
      File.read(opts[:pid]).chomp.to_i
    end

  end
end
