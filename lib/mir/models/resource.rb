require 'digest/md5'

# Represents a local file asset
module Mir
  module Models
    class Resource < ActiveRecord::Base
      
      scope :not_indexed_on, lambda { |date| where("last_indexed_at != ?", date) }
      
      # Builds a resource for the backup index from a file
      # @param [File] a file object
      # @param [String] the name of the file on the remote disk
      # @returns [Resource] a new Resource instance that with a queued status
      def self.create_from_file_and_name(file, name)
        is_dir = File.directory?(file)
        create(:filename => name,
               :size => file.size,
               :last_modified => file.ctime,
               :add_date => DateTime.now,
               :queued => !is_dir,
               :checksum => is_dir ? nil : Digest::MD5.file(file).to_s,
               :is_directory => is_dir)
      end
      
      ##
      # Removes all resources not that were not indexed on the specified date
      #
      # @param [DateTime]
      def self.delete_all_except(index_date)
        not_indexed_on(index_date).delete_all
      end
      
      # Returns true when jobs are still queued
      def self.pending_jobs?
        self.where(:queued => true).size > 0
      end
      
      # Yields a Models::Resource object that needs to be synchronized
      def self.pending_sync_groups(response_size, &block)
        qry = lambda { Resource.where(:queued => true, :is_directory => false) }
        chunked_groups(qry, response_size) { |chunk| yield chunk }
      end
      
      # Returns groups of file resources ordered by name
      # @param [Integer] the number of records to return per chunk
      # @yields [Array] instances of Models::Resource
      def self.ordered_groups(group_size = 10)
        qry = lambda { Resource.order(:filename) }
        chunked_groups(qry, group_size) { |chunk| yield chunk }
      end
      
      def self.chunked_groups(qry_func, chunk_size)
        num_results = Resource.count
        offset = 0
        pages = (num_results/chunk_size.to_f).ceil
        pages.times do |i|
          response = qry_func.call().limit(chunk_size).offset(i*chunk_size)
          yield response
        end
      end
      
      #
      # Compares a file asset to the index to deterimine whether the file needs to be updated
      #
      # @param [String] a path to a file or directory
      # @return [Boolean] returns true when the file's checksum is equal to the value stored in
      #   the index, or when the file is a directory
      def synchronized?(file)
        if File.directory?(file)
          return true
        elsif !File.exist?(file) or in_progress? or queued?
          return false
        else
          Digest::MD5.file(file).to_s == self.checksum
        end
      end
      
      # Whether the item can be synchronized to a remote disk
      # @returns [Boolean] true when the resource is not a directory
      def synchronizable?
        !is_directory?
      end
      
      # Places the resource into a queueble state
      def flag_for_update
        update_attributes :queued => true, 
                          :checksum => Digest::MD5.file(abs_path).to_s,
                          :last_modified => File.new(abs_path).ctime
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
        will_requeue = (num_times_failed < Mir::Application.config.max_upload_attempts)
        update_attributes :times_failed => num_times_failed, :in_progress => false, :queued => will_requeue
      end
      
      def abs_path
        File.join(Models::AppSetting.backup_path, filename)
      end

    end
  end
end