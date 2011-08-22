# Represents a local file asset
module A3backup
  module Models
    class Resource < ActiveRecord::Base
      # Builds a resource for the backup index from a file
      # @param [File] a file object
      # @returns [Resource] a new Resource instance that with a queued status
      def self.create_from_file(file)
        create(:filename => File.basename(file),
               :size => file.size,
               :last_modified => file.ctime,
               :add_date => DateTime.now,
               :queued => true)
      end
      
      # Compares a file asset to the index to deterimine whether the file needs to be updated
      # @param [File] a file object
      # @returns [Boolean] whether the file and index are in sync with each other
      def synchronized?(file)
        (file.size == self.size) and (file.ctime.to_s == last_modified.to_s)
      end
    end
  end
end