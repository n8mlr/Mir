module A3backup
  
  class Application
        
    # Creates a new A3backup instance
    def self.start
      new.start
    end
    
    attr_reader :options
    
    def initialize
      @options = A3backup::Options.parse(ARGV)
      A3backup.logger = Logger.new(options.log_destination)
    end
    
    def start
      if ARGV.size < 2
        puts A3backup::Options::USAGE_BANNER
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