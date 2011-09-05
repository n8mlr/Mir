module Mir
  module Models
    class AppSetting < ActiveRecord::Base
      
      SYNC_PATH = "sync_path"
      INSTALL_DATE = "installation_date"
      
      def self.backup_path
        record = self.where(:name => SYNC_PATH).first
        record.value rescue nil
      end

    end
  end
end