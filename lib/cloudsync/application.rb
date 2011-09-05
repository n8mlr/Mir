require 'fileutils'

module Cloudsync
  
  class Application
    
    DEFAULT_SETTINGS_FILE_NAME = "cloudsync_settings.yml"
    DEFAULT_BATCH_SIZE = 20
        
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
      if options.copy && options.flush
        Cloudsync.logger.error "Conflicting options: Cannot copy from remote source with an empty file index"
        exit
      end
      
      @@config = Config.new find_settings_file
      param_path = File.expand_path(ARGV[0])
      exit unless config.valid?
      
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
      # Returns a path to the settings file. If the file was provided as an option it will always
      # be returned. When no option is passed, the file 'cloudsync_settings.yml' will be searched for
      # in the following paths: $HOME, /etc/cloudsync
      # @return [String] path to the settings or nil if none is found
      def find_settings_file
        if !options.settings_path.nil?
          return options.settings_path
        else
          ["~", "/etc/cloudsync"].each do |dir|
            path = File.expand_path(File.join(dir, DEFAULT_SETTINGS_FILE_NAME))
            return path.to_s if File.exist?(path)
          end
        end
        nil
      end
      
      # Synchronize the local files to the disk
      def push(target)
        Cloudsync.logger.info "Starting push operation"
        if Models::AppSetting.backup_path != target
          Cloudsync.logger.error "Target does not match directory stored in index"
          exit
        end
        # TODO - need to do a check here to see if the target directory has changed
        # from what we've stored locally. If so, we'll need to rebuild the index manually
        
        @index.update
        time = Benchmark.measure do
          queue = WorkQueue.new(config.max_threads)
          
          Models::Resource.pending_sync_groups(DEFAULT_BATCH_SIZE) do |resources|
            resources.each do |resource|
              next if resource.is_directory?
              queue.enqueue_b do
                begin
                  resource.start_progress
                  @disk.write resource.abs_path
                  resource.update_success
                rescue Exception => e
                  Cloudsync.logger.error e.message
                  resource.update_failure
                end
              end
            end
            queue.join
          end
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
          Models::Resource.ordered_groups(DEFAULT_BATCH_SIZE) do |resources|
            resources.each do |resource|
              dest = File.join(write_dir.path, resource.filename)          
              if resource.is_directory?  
                Utils.try_create_dir(dest)
              elsif !resource.synchronized?(dest)
                queue.enqueue_b { @disk.copy(resource.abs_path, dest) }
              end
            end
            queue.join
          end
        end
        Cloudsync.logger.info time
      end
          
  end
end