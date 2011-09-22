require 'active_record'
require "active_support/inflector"

# Manages database operations for application
module Mir
  class Index
    
    MIGRATIONS_PATH = File.join(File.dirname(__FILE__), "..", "..", "db", "migrate")
    
    # Returns a databse object used to connect to the indexing database
    # @param [Hash] database configuration settings. See ActiveRecord#Base::establish_connection
    def initialize(sync_path, connection_params)
      @sync_path = sync_path
      @connection_params = connection_params
    end
    
    attr_reader :sync_path
    
    # Creates necessary database and tables if this is the first time connecting
    # @option opts [Boolean] :verbose Enable on ActiveRecord reporting
    # @option opts [Boolean] :force_flush Rebuild index no matter what
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
    
    # Scans the filesystem and flags any resources which need updating
    def update
      Mir.logger.info "Updating backup index for '#{sync_path}'"
      Models::AppSetting.last_indexed_at = @last_indexed_at = DateTime.now
      
      Dir.glob(File.join(sync_path, "**", "*")) do |f|
        Mir.logger.debug "Index: evaluating '#{f}'"
        next if File.directory? (f)
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
    
    def orphans
      Models::Resource.not_indexed_on(last_indexed_at)
    end
    
    def last_indexed_at
      @last_indexed_at ||= Models::AppSetting.last_indexed_at
    end
    
    
    ##
    # Removes any files from the index that are no longer present locally
    def clean!
      Models::Resource.delete_all_except(last_indexed_at)
    end
    
    private
      # Returns the path of a file relative to the backup directory
      def relative_path(file)
        File.absolute_path(file).gsub(sync_path,'')
      end
      
      # Regenerates the file system index for the backup directory
      def rebuild
        tables.each { |t| ActiveRecord::Migration.drop_table(t.table_name) if t.table_exists? }
        ActiveRecord::Migration.drop_table(:schema_migrations) if @connection.table_exists? :schema_migrations
        ActiveRecord::Migrator.migrate MIGRATIONS_PATH
        Models::AppSetting.initialize_table(sync_path)
      end
      
      
      ##
      # TODO: no reason to lazy load these activemodels
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
      
      # Returns the activerecord classes for each table used by the application
      def tables
        @tables
      end
      
      # Checks whether any of the tables required by the applicaiton exist
      def tables_created?
        tables.any? { |t| t.table_exists? }
      end
  end
end