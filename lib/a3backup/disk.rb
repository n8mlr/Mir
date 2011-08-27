# The remote storage container where objects are saved
module A3backup
  module Disk
    
    # Returns a disk object from the settings specified
    def self.fetch(settings = {})
      case settings[:type]
      when "s3"
        A3backup::Disk::Amazon.new(settings)
      else
        A3backup.logger.error "Could not find specified cloud provider"
      end
    end


  end
end