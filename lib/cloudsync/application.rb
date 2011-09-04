require 'fileutils'

module Cloudsync
  
  class Application
        
    # Creates a new Cloudsync instance
    def self.start
      new.start
    end
    
    attr_reader :options
    
    def initialize
      @options = Cloudsync::Options.parse(ARGV)
      Cloudsync.logger = Logger.new(options.log_destination)
    end
    
    def start
      if ARGV.size < 2
        puts Cloudsync::Options::USAGE_BANNER
        exit
      end
      
      if options.copy && options.flush
        Cloudsync.logger.error "Conflicting options: Cannot copy from remote source with an empty file index"
        exit
      end
      
      @@config = Config.new(ARGV[0])
      param_path = File.expand_path(ARGV[1])
      
      if config.valid?
        Cloudsync.logger.info("Starting application")
      else
        Cloudsync.logger.error("Configuration file is not valid")
        exit
      end
      
      # Initialize our remote disk
      @disk = Disk.fetch(config.cloud_provider)
      exit unless @disk.connected?
      
      # Initialize our local index
      @index = Index.new(param_path, config.database)
      @index.setup(:verbose => options.verbose, :force_flush => options.flush)
      
      options.copy ? pull(param_path) : push(param_path)
    end
  
    def self.config
      @@config
    end
    
    def config
      @@config
    end
    
    private
      
      # Synchronize the local files to the disk
      def push(target)
        Cloudsync.logger.info "Starting push operation"
        if Models::AppSetting.backup_path != target
          Cloudsync.logger.error "Target does not match directory stored in index"
          exit
        end
        # need to do a check here to see if the target directory has changed
        # from what we've stored locally. If so, we'll need to rebuild the index manually
        @index.update
        time = Benchmark.measure do
          queue = WorkQueue.new(config.max_threads)
          
          Models::Resource.pending_sync do |resource|
            unless resource.is_directory?
              resource.start_progress
              begin
                queue.enqueue_b {
                  @disk.write resource.abs_path
                  resource.update_success
                }
              rescue Exception => e
                Cloudsync.logger.error e.message
                resource.update_failure
              end
            end
          end
          queue.join
        end
        Cloudsync.logger.info time
      end
      
      # Copy the remote disk contents into the specified directory
      def pull(target)
        Utils.try_create_dir(target)
        write_dir = Dir.new(target)
        Cloudsync.logger.info "Copying remote disk to #{write_dir.path} using #{config.max_threads} threads"
        
        time = Benchmark.measure do 
          queue = WorkQueue.new(config.max_threads)
        
          # loop through each resource. If the resource is a directory, create the path
          # otherwise download the file
          Models::Resource.chunked_by_name do |resource|
            dest = File.join(write_dir.path, resource.filename)          
            if resource.is_directory?  
              Utils.try_create_dir(dest)
            elsif !resource.synchronized?(dest)
              queue.enqueue_b { @disk.copy(resource.abs_path, dest) }
            end
          end
          queue.join
        end
        
        Cloudsync.logger.info time
      end
          
  end
end