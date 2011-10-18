require 'unicorn/launcher'
require 'logger'

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
      @leader = opts.delete(:leader)
      @config_file = conf
      logger.info "Initializing Blessing::Runner for #{conf}"
      @opts = DEFAULT_OPTS.merge opts
      parse_configuration
    end

    # Tap on leader logger facility or create one
    def logger
      if @leader
        @leader.logger
      else
        # We don't have leader connected, wont clutter stdout with log
        unless @logger
          @logger = Logger.new '/dev/null'
        end
        @logger
      end
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
      logger.info "Starting Unicorn! process for #{@config_file.inspect}"
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
      logger.info "Stopping Unicorn! process for #{@config_file.inspect}"
      # Lets not panic if the process is already dead
      begin
        Process.kill "QUIT", pid
      rescue => e
        logger.warn "Process does not exist! PID=#{pid}, conf=#{@config_file.inspect}"
      end
    end

    # Reload Unicorn if needed
    # Ensure it did start up
    # (This is the main cycle of Leader control)
    def check_reload(resurrect=false)
      logger.debug "Verifying #{@config_file.inspect}"

      # See if this Unicorn is alread dead
      if dead?
        logger.warn "This Unicorn is dead: PID=#{pid}, conf=#{@config_file.inspect}"
        unless resurrect
          return
        else 
          logger.warn "Resurrecting..."
        end
      end

      # If configuration has changed, reload Unicorn
      if config_modified?
        reload
      end

      # In any case ensure it is running
      ensure_running

      # if it was dead and is now running, we are successful
      if dead? && running?
        logger.warn "Successfully resurrected (necromancy +1)!"
        @dead = false
      else
        logger.warn "Resurrection failed!"
      end
    end

    # Reload Unicorn! master process
    def reload
      logger.info "Reloading #{@config_file.inspect}"
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

    # is it totally dead?
    def dead?
      @dead
    end

    # Ensure the Unicorn! process is running
    # restarting it if needed
    def ensure_running
      unless success = running?
        logger.info "Process is not running: pid=#{pid} conf=#{@config_file.inspect}"
        opts[:max_restarts].times do |i|
          logger.info "Restarting: try=#{i+1}"
          start
          sleep opts[:retry_delay]
          break if success = running?
        end
        if success
          logger.info "Successfully restarted"
          # just in case it was dead before
          @dead = false
        else
          logger.warn "Failed to restart in #{opts[:max_restarts]} tries, conf=#{@config_file.inspect}"
          @dead = true
        end
      end
      success
    end

    private
    # Read PID from pid-file
    def pid
      if File.exists? opts[:pid]
        File.read(opts[:pid]).chomp.to_i
      else
        logger.warn "PID-file does not exist! Pidfile= #{@opts[:pid].inspect}, conf=#{@config_file.inspect}"
        nil
      end
    end

  end
end
