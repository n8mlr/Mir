# Represents a local file asset
module A3backup
  module Models
    class Resource < ActiveRecord::Base
      
      scope :pending_jobs, select(:id).where(:queued => true)
      
      # Builds a resource for the backup index from a file
      # @param [File] a file object
      # @returns [Resource] a new Resource instance that with a queued status
      def self.create_from_file(file)
        create(:filename => File.absolute_path(file),
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
      
      def start_progress
        update_attribute :in_progress, true
      end
      
      def update_success
        update_attributes :in_progress => false, 
                          :last_synchronized => DateTime.now, 
                          :queued => false,
                          :times_failed => 0
      end
      
      def update_failure
        num_times_failed = times_failed + 1
        will_requeue = (num_times_failed < A3backup::Application.config.max_upload_retries)
        update_attributes :times_failed => num_times_failed, :in_progress => false, :queued => will_requeue
      end
    end
  end
end