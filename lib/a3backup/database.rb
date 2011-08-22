require 'active_record'
require "active_support/inflector"

# Manages database operations for application
module A3backup
  class Database
    
    MIGRATIONS_PATH = File.join(File.dirname(__FILE__), "..", "..", "db", "migrate")
    
    # Returns a databse object used to connect to the indexing database
    # @param [Hash] database configuration settings. See ActiveRecord#Base::establish_connection
    def initialize(connection_params)
      @connection_params = connection_params
    end
    
    # Creates necessary database and tables if this is the first time connecting
    def setup(options = {})
      ActiveRecord::Base.establish_connection(@connection_params)
      ActiveRecord::Base.timestamped_migrations = false
      
      if options[:verbose]
        ActiveRecord::Base.logger = A3backup.logger
        ActiveRecord::Migration.verbose = true
      end
      
      flush_db = options[:force_flush] || false
      flush_db = true unless tables_created?
      if flush_db
        flush
        Models::AppSetting.create(:name => "installation_date", :value => DateTime.now.to_s)
      end
    end
    
    private
      # Returns the activerecord classes for each table used by the application
      def tables
        models = File.join(File.dirname(__FILE__), "models", "*.rb")
        classes = []

        Dir.glob(models) do |f|
          name = "Models::" + ActiveSupport::Inflector.camelize(File.basename(f, ".rb"))
          classes << eval(name)
        end
        classes
      end
      
      # Checks whether any of the tables required by the applicaiton exist
      def tables_created?
        tables.any? { |t| t.table_exists? }
      end
      
      # Drops all tables and runs migrations
      def flush
        tables.each { |t| ActiveRecord::Migration.drop_table(t.table_name) if t.table_exists? }
        ActiveRecord::Migration.drop_table(:schema_migrations)
        ActiveRecord::Migrator.migrate MIGRATIONS_PATH
      end

  end
end