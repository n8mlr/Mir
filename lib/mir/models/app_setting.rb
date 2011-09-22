module Mir
  module Models
    class AppSetting < ActiveRecord::Base

      ##
      # Builds entries for the variables that will be used by this application
      # 
      # @param [String] the path to be synchronized with S3
      def self.initialize_table(sync_path)
        create(:name => :sync_path, :value => sync_path)
        create(:name => :install_date, :value => DateTime.now)
        create(:name => :last_indexed_at, :value => nil)
      end
      
      def self.backup_path
        where(:name => :sync_path).first.value
      end
      
      def self.last_indexed_at=(val)
        record = where(:name => :last_indexed_at).first
        record.update_attribute(:value, val)
      end
      
      def self.last_indexed_at
        where(:name => :last_indexed_at).first.value
      end

    end
  end
end