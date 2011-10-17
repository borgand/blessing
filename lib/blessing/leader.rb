require 'logger'
require 'daemons'

module Blessing

  # Blessing::Leader is the main class and entry point
  class Leader

    DefaultOptions = {
      # Run as daemon
      :daemonize => false,
      # Monitoring refresh cycle legth in seconds
      :refresh => 10,
      :verbose => false,
      :log => STDOUT,
    }

    attr_accessor :patterns, :config_files, :old_config_files, :runners, :logger

    # Initialize new Blessing::Leader with file list pattern
    def initialize patterns, opts = {}
      @options = DefaultOptions.merge(opts)
      initialize_logger

      logger.info "Starting Blessing::Leader"
      @patterns = patterns.is_a?(Array) ? patterns : [patterns]
      logger.debug "Patterns: #{patterns.inspect}"

      @old_confdig_files = @config_files = []
      @runners = {}

      # Trap some signals
      trap("INT"){
        logger.info "Caught SIGINT"
        at_exit
      }
      trap("TERM"){
        logger.info "Caught SIGTERM"
        at_exit
      }
    end

    def initialize_logger
      @logger = Logger.new @options[:log]
      @logger.level = @options[:verbose] ? Logger::DEBUG : Logger::INFO
    end

    def daemonize!
      logger.info "Daemonizing..."
      Daemons.daemonize
    end

    # Daemons hook to shut down properly
    def at_exit
      logger.info "Shutting down"
      stop
    end

    # Start running cycles
    def start
      logger.info "Starting cycles"
      daemonize! if @options[:daemonize]
      @run_cycles = true
      while @run_cycles do
        run_cycle
        sleep @options[:refresh]
      end
    end

    # Stop running cycles
    def stop
      @run_cycles = false
      logger.debug "Stopping all runners..."
      stop_runners @config_files
      logger.info "All runners stopped"
    end

    # Main cycle
    # - refresh file list
    # - start/stop runners
    # - verify/reload runners
    def run_cycle
      logger.debug "Next cycle"
      refresh_file_list
      start_stop_runners
      reload_runners
    end

    # Refresh config file list and preserve old list
    def refresh_file_list
      logger.debug "Refreshing file list"
      # Preserve old file list
      @old_config_files = @config_files

      files = []
      @patterns.each{|p| files += Dir.glob(p)}
      @config_files = files.uniq.sort
      logger.debug "Found files: #{@config_files.inspect}"
    end

    # Find differences in old and new config file lists
    # and start/stop runners as appropriate
    def start_stop_runners
      start_runners @config_files - @old_config_files
      stop_runners @old_config_files - @config_files
    end


    # Start runners for added config files
    def start_runners(files)
      logger.debug "Starting runners for: #{files.inspect}" unless files.empty?
      files.each { |conf|
        @runners[conf] = runner = Blessing::Runner.new(conf, :leader => self)
        runner.start
      }
    end

    # Stop runners for missing config files
    def stop_runners(files)
      logger.debug "Stopping runners for: #{files.inspect}" unless files.empty?
      files.each { |conf| 
        if @runners[conf]
          @runners[conf].stop
          @runners.delete(conf)
        end
      }
    end

    # Let each runner check itself if reload is needed
    def reload_runners
      @runners.each_value do |runner|
        runner.check_reload
      end
    end

  end

end
