module Cloudsync
  class Options
    
    USAGE_BANNER = "Usage: cloudsync [options] [settings_file_path] [target]"
    
    def self.parse(args)
      options = OpenStruct.new
      options.debug = false
      options.verbose = false
      options.settings_file = nil
      options.log_destination = STDOUT
      options.flush = false
      options.copy = false
      options.settings_path = nil
      
      opts_parser = OptionParser.new do |opts|
        opts.banner = USAGE_BANNER
        opts.separator ""
        opts.separator "Specific options:"
        
        opts.on("--flush", "Flush the file index") do
          options.flush = true
        end
        
        opts.on("-c", "--copy", "Copy the remote files to target") do
          options.copy = true
        end
        
        opts.on("--settings", String, "The YAML settings file") do |path|
          options.settings_path = path
        end
        
        opts.on("-l", "--log-path LOG_FILE", String, "Location for storing execution logs") do |log_file|
          options.log_destination = log_file
        end
        
        opts.on("-v", "--verbose", "Run verbosely") do |v|
          options.verbose = true
        end
        
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
        
        opts.on_tail("--version", "Show version") do
          puts Cloudsync.version
          exit
        end
      end
      
      opts_parser.parse!(args)
      options
    end
  end  
end