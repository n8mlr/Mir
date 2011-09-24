# The remote storage container where objects are saved
module Mir
  module Disk
    
    class IncompleteTransmission < StandardError ; end
    class RemoteFileNotFound < StandardError ; end
    
    # Returns a disk object from the settings specified
    # @return [Mir::Disk]
    def self.fetch(settings = {})
      case settings[:type]
      when "s3"
        Mir::Disk::Amazon.new(settings)
      else
        Mir.logger.error "Could not find specified cloud provider"
      end
    end


  end
end