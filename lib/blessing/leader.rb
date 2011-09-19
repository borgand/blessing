module Blessing

  # Blessing::Leader is the main class and entry point
  class Leader

    DefaultOptions = {
      # Monitoring refresh cycle legth in seconds
      :refresh => 10,
    }

    attr_accessor :pattern, :config_files, :old_config_files, :runners

    # Initialize new Blessing::Leader with file list pattern
    def initialize pattern, opts = {}
      @pattern = pattern
      @old_confdig_files = @config_files = []
      @runners = {}
      @options = DefaultOptions.merge(opts)
    end

    # Start running cycles
    def start
      @run_cycles = true
      while true do
        break unless @run_cycles
        run_cycle
        sleep @options[:refresh]
      end
    end

    # Stop running cycles
    def stop
      @run_cycles = false
    end

    # Main cycle
    # - refresh file list
    # - start/stop runners
    # - verify/reload runners
    def run_cycle
      refresh_file_list
      start_stop_runners
      reload_runners
    end

    # Refresh config file list and preserve old list
    def refresh_file_list
      # Preserve old file list
      @old_config_files = @config_files
      @config_files = Dir.glob @pattern
    end

    # Find differences in old and new config file lists
    # and start/stop runners as appropriate
    def start_stop_runners
      start_runners @config_files - @old_config_files
      stop_runners @old_config_files - @config_files
    end


    # Start runners for added config files
    def start_runners(files)
      files.each { |conf|
        @runners[conf] = runner = Blessing::Runner.new(conf)
        runner.start
      }
    end

    # Stop runners for missing config files
    def stop_runners(files)
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
