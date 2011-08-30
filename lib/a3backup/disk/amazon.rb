module A3backup
  module Disk
    class Amazon
      
      attr_reader :bucket_name
      
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
      
      # Copies the remote resource to the local filesystem
      # @param [String] the remote name of the resource to copy
      # @param [String] the local name of the destination
      def copy(from, to)
        open(to, 'w') do |file|
          AWS::S3::S3Object.stream(from, volume.name) { |chunk| file.write(chunk) }
        end
        A3backup.logger.info "Completed download '#{to}'"
      end
      
      def connected?
        @connection_success
      end
      
      def volume
        begin
          AWS::S3::Bucket.find(bucket_name)          
        rescue AWS::S3::NoSuchBucket => e
          A3backup.logger.info "Could not find bucket named '#{bucket_name}'"
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
        
        # Create the remote bucket
        def create_bucket
          AWS::S3::Bucket.create(bucket_name)
        end
      
    end
  end
end