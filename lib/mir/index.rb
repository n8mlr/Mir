require 'active_record'
require "active_support/inflector"

# The index class is responsible for maintaining knowledge of files uploaded
# onto the remote file system. The index does this by scanning the directory to
# be synchronized and evaluating whether a file needs to be uploaded or has changed
# since the last indexing date

module Mir
  class Index
    
    MIGRATIONS_PATH = File.join(File.dirname(__FILE__), "..", "..", "db", "migrate")
    
    # Returns a databse object used to connect to the indexing database
    #
    # @param sync_path [String] the absolute path of the directory to be synchronized
    # @param connection_params [Hash] database configuration settings. See ActiveRecord#Base::establish_connection
    # @return [Mir::Index]
    def initialize(sync_path, connection_params)
      @sync_path = sync_path
      @connection_params = connection_params
    end
    
    attr_reader :sync_path
    
    #
    # Creates necessary database and tables if this is the first time connecting
    #
    # @option options [Boolean] :verbose Enable on ActiveRecord reporting
    # @option options [Boolean] :force_flush Rebuild index no matter what
    # @return [void]
    def setup(options = {})
      options[:force_flush] ||= false
      options[:verbose] ||= false
      @connection = ActiveRecord::Base.establish_connection(@connection_params).connection
      ActiveRecord::Base.timestamped_migrations = false
      
      if options[:verbose]
        ActiveRecord::Base.logger = Mir.logger
        ActiveRecord::Migration.verbose = true
      end
      
      load_tables
      rebuild if !tables_created? or options[:force_flush]
    end
    
    ##
    # Scans the synchronization path and evaluates whether a resource has changed
    # since the last index or is new and needs to be added to the index.
    # @return [void]
    def update
      Mir.logger.info "Updating backup index for '#{sync_path}'"
      Models::AppSetting.last_indexed_at = @last_indexed_at = DateTime.now
      
      Dir.glob(File.join(sync_path, "**", "*")) do |f|
        fname = relative_path(f)
        file = File.new(f)
        resource = Models::Resource.find_by_filename(fname)

        if resource.nil?
          Mir.logger.debug "Adding file to index #{fname}"
          resource = Models::Resource.create_from_file_and_name(file, fname)
        elsif !resource.synchronized?(file)
          resource.flag_for_update
        end
        resource.update_attribute(:last_indexed_at, last_indexed_at)
      end
      
      Mir.logger.info "Index updated"
    end
    
    ##
    # Returns any files not present since the last re-indexing. This is useful
    # for finding files that have been deleted post-index.
    # 
    # @return [Array, Mir::Models::Resource]
    def orphans
      Models::Resource.not_indexed_on(last_indexed_at)
    end
    
    ##
    # The date at whish the backup path was last indexed
    # @return [DateTime]
    def last_indexed_at
      @last_indexed_at ||= Models::AppSetting.last_indexed_at
    end
    
    
    ##
    # Removes any files from the index that are no longer present locally
    # @return [void]
    def clean!
      Models::Resource.delete_all_except(last_indexed_at)
    end
    
    private
      ##
      # Returns the path of a file relative to the backup directory
      # @param file [String] the absolute path name of the file
      # @return [String] the path of the file relative to the stored backup path
      def relative_path(file)
        File.absolute_path(file).gsub(sync_path,'')
      end
      
      ##
      # Regenerates the file system index for the backup directory
      # @return [void]
      def rebuild
        tables.each { |t| ActiveRecord::Migration.drop_table(t.table_name) if t.table_exists? }
        ActiveRecord::Migration.drop_table(:schema_migrations) if @connection.table_exists? :schema_migrations
        ActiveRecord::Migrator.migrate MIGRATIONS_PATH
        Models::AppSetting.initialize_table(sync_path)
      end
      
      
      ##
      # Loads ActiveRecord tables
      # @todo no reason to lazy load these activemodels
      def load_tables
        @tables = []
        models = File.join(File.dirname(__FILE__), "models", "*.rb")
        
        # load the AR models for the application
        Dir.glob(models) do |f|
          require f
          name = "Models::" + ActiveSupport::Inflector.camelize(File.basename(f, ".rb"))
          @tables << eval(name)
        end
      end
      
      ##
      # Returns the activerecord classes for each table used by the application
      # @return [Array, Class]
      def tables
        @tables
      end
      
      ##
      # Checks whether any of the tables required by the application exist
      # @return [Boolean]
      def tables_created?
        tables.any? { |t| t.table_exists? }
      end
  end
end