# Represents a local file asset
module A3backup
  module Models
    class Resource < ActiveRecord::Base
      
      scope :pending_jobs, select(:id).where(:queued => true)
      
      # Builds a resource for the backup index from a file
      # @param [File] a file object
      # @param [String] the name of the file on the remote disk
      # @returns [Resource] a new Resource instance that with a queued status
      def self.create_from_file_and_name(file, name)
        create(:filename => name,
               :size => file.size,
               :last_modified => file.ctime,
               :add_date => DateTime.now,
               :queued => true,
               :is_directory => File.directory?(file))
      end
      
      # Yields a Models::Resource object that needs to be synchronized
      def self.pending_sync(&block)
        resource_ids = Resource.pending_jobs
        resource_ids.each { |rid| yield Resource.find(rid) }
      end
      
      def self.chunked_by_name(page_size = 10)
        num_results = Resource.count
        offset = 0
        pages = (num_results/page_size.to_f).ceil
        pages.times do |i|
          resources = Resource.order(:filename).limit(page_size).offset(i*page_size)
          resources.each { |r| yield r }
        end
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
      
      def abs_path
        File.join(Models::AppSetting.backup_path, filename)
      end
      
      # Checks whether the local resource is different from what is stored in the index
      # @param [String] the path of the resource to be compared
      # @returns [Bool] whether the resource has changed
      def changed?(local_path)
        File.size?(local_path) != self.size
      end
    end
  end
end