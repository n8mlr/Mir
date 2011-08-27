module A3backup
  module Models
    class AppSetting < ActiveRecord::Base
      
      def self.backup_path
        record = self.where(:name => "backup_path").first
        record.value rescue nil
      end
    end
  end
end