require 'optparse'
require 'ostruct'

module A3backup
  class Application
    class Options
      def self.parse(args)
        options = OpenStruct.new
        options.debug = false
        options.verbose = false
        options.settings_file = nil
        options.log_destination = STDOUT
        options.flush_db = false
        
        opts_parser = OptionParser.new do |opts|
          opts.banner = "Usage: a3backup [setings] [directory] [options]"
          opts.separator ""
          opts.separator "Specific options:"
          
          opts.on("--flush-db", "Flush all database tables and rebuild index") do
            options.flush_db = true
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
    
    def logger
      A3backup.logger
    end
    
    def start
      @config = Config.new(ARGV[0])
      @backup_path = ARGV[1]
      
      if @config.valid?
        logger.info("Starting application")
      else
        logger.error("Configuration file is not valid")
        exit
      end
      
      @database = Database.new(@config.database)
      @database.setup(:force_flush => options.flush_db, :verbose => options.verbose)
      
      update_index
    end
    
    private
      def update_index
        logger.info "Updating backup index"
        Dir.glob(File.join(@backup_path, "**")) do |f|
          fname = File.basename(f)
          file = File.new(f)
          resource = Models::Resource.find_by_filename(fname)

          if !resource
            puts "Adding file to index #{fname}"
            resource = Models::Resource.create_from_file(file)
          else
            unless resource.synchronized?(file)
              puts "#{fname} is out of sync"
            end
          end
                              
        end
        logger.info "Backup index completed"
      end
      
        
  end
end