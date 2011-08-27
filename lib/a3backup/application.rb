require 'optparse'
require 'ostruct'

module A3backup
  class Application
    class Options
      
      USAGE_BANNER = "Usage: a3backup [options] [settings_file_path] [backup_directory]"
      
      def self.parse(args)
        options = OpenStruct.new
        options.debug = false
        options.verbose = false
        options.settings_file = nil
        options.log_destination = STDOUT
        options.flush = false
        
        opts_parser = OptionParser.new do |opts|
          opts.banner = USAGE_BANNER
          opts.separator ""
          opts.separator "Specific options:"
          
          opts.on("--flush", "Flush the file index") do
            options.flush = true
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
            puts A3backup.version
            exit
          end
        end
        
        opts_parser.parse!(args)
        options
      end
    end
    
    # Creates a new A3backup instance
    def self.start
      new.start
    end
    
    
    attr_reader :options
    
    def initialize
      @options = Options.parse(ARGV)
      A3backup.logger = Logger.new(options.log_destination)
    end
    
    def start
      if ARGV.size < 2
        puts Options::USAGE_BANNER
        exit
      end
      
      @@config = Config.new(ARGV[0])
      param_path = File.expand_path(ARGV[1])
      
      if config.valid?
        A3backup.logger.info("Starting application")
      else
        A3backup.logger.error("Configuration file is not valid")
        exit
      end
      
      disk = Disk.fetch(config.cloud_provider)
      exit unless disk.connected?
      
      index = Index.new(param_path, config.database)
      index.setup(:verbose => options.verbose, :force_flush => options.flush)
      index.update
      
      index.files_pending_sync do |resource|
        file_path = resource.filename
        resource.start_progress
        begin
          disk.write file_path
          resource.update_success
        rescue Exception => e
          A3backup.logger.error e.message
          resource.update_failure
        end
      end
    end
  
    def self.config
      @@config
    end
    
    def config
      @@config
    end
    
  end
end