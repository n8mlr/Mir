module A3backup
  module Disk
    class Amazon
      
      def initialize(settings = {})
        @bucket_name = settings[:bucket_name]
        @access_key_id = settings[:access_key_id]
        @secret_access_key = settings[:secret_access_key]
        @connection = try_connect
        create_bucket if volume.nil?
      end
      
      # Returns the buckets available from S3
      def collections
        AWS::S3::Service.buckets
      end
      
      def connected?
        @connection_success
      end
      
      def volume
        begin
          AWS::S3::Bucket.find(@bucket_name)          
        rescue AWS::S3::NoSuchBucket => e
        end
      end
      
      def write(file_path)
        AWS::S3::S3Object.store(file_path, open(file_path), volume.name)
      end
      
      private
        def try_connect
          begin
            AWS::S3::Base.establish_connection!(
              :access_key_id => @access_key_id,
              :secret_access_key => @secret_access_key
            )
            @connection_success = true
          rescue Exception => e
            @connection_success = false
            A3Backup.logger.error "Could not establish connection with S3: '#{e.message}'"
          end
        end
        
        def create_bucket
          AWS::S3::Bucket.create(@bucket_name)
        end
      
    end
  end
end