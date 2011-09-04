# The remote storage container where objects are saved
module Cloudsync
  module Disk
    
    # Returns a disk object from the settings specified
    def self.fetch(settings = {})
      case settings[:type]
      when "s3"
        Cloudsync::Disk::Amazon.new(settings)
      else
        Cloudsync.logger.error "Could not find specified cloud provider"
      end
    end


  end
end