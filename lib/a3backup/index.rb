require 'active_record'
require "active_support/inflector"

# Manages database operations for application
module A3backup
  class Index
    
    MIGRATIONS_PATH = File.join(File.dirname(__FILE__), "..", "..", "db", "migrate")
    
    # Returns a databse object used to connect to the indexing database
    # @param [Hash] database configuration settings. See ActiveRecord#Base::establish_connection
    def initialize(backup_path, connection_params)
      @backup_path = backup_path
      @connection_params = connection_params
    end
    
    attr_reader :backup_path
    
    # Creates necessary database and tables if this is the first time connecting
    # @option opts [Boolean] :verbose Enable on ActiveRecord reporting
    # @option opts [Boolean] :force_flush Rebuild index no matter what
    def setup(options = {})
      options[:force_flush] ||= false
      options[:verbose] ||= false
      @connection = ActiveRecord::Base.establish_connection(@connection_params).connection
      ActiveRecord::Base.timestamped_migrations = false
      
      if options[:verbose]
        ActiveRecord::Base.logger = A3backup.logger
        ActiveRecord::Migration.verbose = true
      end
      
      load_tables
      
      stored_backup_path = Models::AppSetting.backup_path
      if !tables_created? or backup_path != stored_backup_path or options[:force_flush]
        rebuild     
      end
    end
    
    # Updates the index for the file directory path
    def update
      A3backup.logger.info "Updating backup index for '#{backup_path}'"
      Dir.glob(File.join(backup_path, "**", "*")) do |f|
        fname = File.absolute_path(f)
        file = File.new(f)
        resource = Models::Resource.find_by_filename(fname)

        if !resource
          puts "Adding file to index #{fname}"
          resource = Models::Resource.create_from_file(file)
        else
          "#{fname} is out of sync" unless resource.synchronized?(file)
        end                
      end
    end
    
    # Yields a Models::Resource object
    def files_pending_sync(&block)
      resource_ids = Models::Resource.pending_jobs
      resource_ids.each { |rid| yield Models::Resource.find(rid) }
    end
    
    private
      
      # Regenerates the file system index for the backup directory
      def rebuild
        tables.each { |t| ActiveRecord::Migration.drop_table(t.table_name) if t.table_exists? }
        ActiveRecord::Migration.drop_table(:schema_migrations) if @connection.table_exists? :schema_migrations
        ActiveRecord::Migrator.migrate MIGRATIONS_PATH
        Models::AppSetting.create(:name => "backup_path", :value => backup_path)
        Models::AppSetting.create(:name => "installation_date", :value => DateTime.now.to_s)
      end
      
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