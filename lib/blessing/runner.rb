module Blessing

  # This class holds all handles to a specific Unicorn instance
  # and through this that Unicorn is manipulated
  class Runner
  
    attr_reader :config_file, :conf

    def initialize conf
      @config_file = conf
      parse_configuration
    end

    # Let Unicorn parse it's config file
    def parse_configuration
      @conf = {}
      conf_str = File.read @config_file

      # Parse parameters we are interested in
      [:pid].each do |key|
        if conf_str =~/#{key} (.*)/
          @conf[key] = eval $1
        end
      end
    end

  end
end
