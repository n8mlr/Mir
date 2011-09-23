require "benchmark"
require "fileutils"
require "work_queue"

module Mir
  
  class Application
    
    DEFAULT_SETTINGS_FILE_NAME = "mir_settings.yml"
    DEFAULT_BATCH_SIZE = 100
        
    # Creates a new Mir instance
    def self.start
      new.start
    end
    
    attr_reader :options, :disk, :index
    
    def initialize
      @options = Mir::Options.parse(ARGV)
      Mir.logger = Logger.new(options.log_destination)
      Mir.logger.level = if options.debug
        Logger::DEBUG
      else
        Logger::ERROR
      end
    end
    
    ##
    # Begins the synchronization operation after initializing the file index and remote storage
    # container
    def start
      if options.copy && options.flush
        Mir.logger.error "Conflicting options: Cannot copy from remote source with an empty file index"
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
    
    ##
    # Returns a global configuration instance
    # 
    # @return [Mir::Config]
    def self.config
      @@config
    end
    
    ##
    # Alias for +config
    def config
      self.class.config
    end
    
    private
      # Returns a path to the settings file. If the file was provided as an option it will always
      # be returned. When no option is passed, the file 'mir_settings.yml' will be searched for
      # in the following paths: $HOME, /etc/mir
      # @return [String] path to the settings or nil if none is found
      def find_settings_file
        if !options.settings_path.nil?
          return options.settings_path
        else
          ["~", "/etc/mir"].each do |dir|
            path = File.expand_path(File.join(dir, DEFAULT_SETTINGS_FILE_NAME))
            return path.to_s if File.exist?(path)
          end
        end
        nil
      end
      
      ##
      # Synchronize the local files to the remote disk
      #
      # @param [String] the absolute path of the folder that will be synchronized remotely
      def push(target)
        Mir.logger.info "Starting push operation"
        
        if Models::AppSetting.backup_path != target
          Mir.logger.error "Target does not match directory stored in index"
          exit
        end
        
        index.update
        
        time = Benchmark.measure do
          queue = WorkQueue.new(config.max_threads)
          while Models::Resource.pending_jobs? do
            Models::Resource.pending_sync_groups(DEFAULT_BATCH_SIZE) do |resources|
              push_group(queue, resources)
              handle_push_failures(resources)
            end
          end
        end
        
        # If any assets have been deleted locally, also remove them from remote disk
        index.orphans.each { |orphan| disk.delete(orphan.abs_path) }
        index.clean! # Remove orphans from index
        puts "Completed push operation #{time}"
        Mir.logger.info time
      end
      
      ##
      # Uploads a collection of resouces. Blocks until all items in queue have been processed
      #
      # @param [WorkQueue] a submission queue to manage resource uploads
      # @param [Array] an array of Models::Resource objects that need to be uploaded
      def push_group(work_queue, resources)
        resources.each do |resource|
          Mir.logger.debug "Enqueueing #{resource.filename}"
          work_queue.enqueue_b do
            resource.start_progress
            disk.write resource.abs_path
            resource.update_success
            puts "Pushed #{resource.abs_path}"
          end
        end
        work_queue.join
      end
      
      #
      # Scans a collection of resources for jobs that did no complete successfully and flags them
      # for resubmission
      #
      # @param [Array] an array of Models::Resources
      def handle_push_failures(resources)
        resources.each do |resource|
          if resource.in_progress?
            Mir.logger.info "Resource '#{resource.abs_path}' failed to upload"
            resource.update_failure 
          end
        end
      end
      
      # Copy the remote disk contents into the specified directory
      def pull(target)
        write_dir = Utils.try_create_dir(target)
        Mir.logger.info "Copying remote disk to #{write_dir.path} using #{config.max_threads} threads"
        failed_downloads = []
        
        time = Benchmark.measure do 
          queue = WorkQueue.new(config.max_threads)
          
          Models::Resource.ordered_groups(DEFAULT_BATCH_SIZE) do |resources|
            # Track the number of download attempts made per resource
            batch = resources.inject({}) { |set, resource| set[resource] = 0; set }
            
            while !batch.empty? do
              batch.each do |resource, attempts|
                dest = File.join(write_dir.path, resource.filename)
                if resource.is_directory?
                  Utils.try_create_dir(dest)
                  batch.delete(resource)
                elsif attempts >= config.max_download_attempts
                  Mir.logger.info "Resource #{resource.abs_path} failed to download"
                  failed_downloads << resource
                  batch.delete(resource)
                elsif resource.synchronized? dest
                  Mir.logger.debug "Skipping already downloaded file #{resource.abs_path}"
                  batch.delete(resource)
                else
                  batch[resource] += 1
                  queue.enqueue_b do
                    Mir.logger.debug "Beginning download of #{resource.abs_path}"
                    disk.copy(resource.abs_path, dest)
                    if resource.synchronized? dest
                      FileUtils.chmod_R 0755, dest # allow binaries to execute
                      puts "Pulled #{dest}"
                      batch.delete(resource)
                    end
                  end
                end
              end
              queue.join
            end
          end
        end
        Mir.logger.info time
        puts "Completed pull operation #{time}"
        unless failed_downloads.empty?
          puts "The following files failed to download after several attempts:\n}"
          puts failed_downloads.join("\n")
        end
      end
          
  end
end