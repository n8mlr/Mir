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
      
      # Initialize our remote disk
      @disk = Disk.fetch(config.cloud_provider)
      exit unless @disk.connected?
      
      # Initialize our local index
      @index = Index.new(param_path, config.database)
      @index.setup(:verbose => options.verbose, :force_flush => options.flush)
      
      if options.copy
        pull(param_path)
      else
        push
      end
    end
  
    def self.config
      @@config
    end
    
    def config
      @@config
    end
    
    private
      
      # Synchronize the local files to the disk
      def push
        # need to do a check here to see if the target directory has changed
        # from what we've stored locally. If so, we'll need to rebuild the index manually
        @index.update
        Models::Resource.pending_sync do |resource|
          resource.start_progress
          begin
            @disk.write resource.abs_path
            resource.update_success
          rescue Exception => e
            A3backup.logger.error e.message
            resource.update_failure
          end
        end
      end
      
      # Copy the remote disk contents into the specified directory
      def pull(target)
        Utils.try_create_dir(target)
        write_dir = Dir.new(target)
        A3backup.logger.info "Copying remote disk to #{write_dir.path}"
        
        # loop through each resource. If the resource is a directory, create the path
        # otherwise download the file
        Models::Resource.chunked_by_name do |resource|
          dest = File.join(write_dir.path, resource.filename)
          
          if resource.is_directory?  
            Utils.try_create_dir(dest)
          else
            # if file already exists, check whether a download is necessary
            if !File.exist?(dest) or resource.changed?(dest)
              @disk.copy(resource.abs_path, dest)
            end
          end
        end
      end
          
  end
end