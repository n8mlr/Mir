module Cloudsync
  module Disk
    class Amazon
      
      attr_reader :bucket_name
      
      def self.key_name(path)
        if path[0] == File::SEPARATOR
          path[1..-1] 
        else
          path
        end
      end
      
      def initialize(settings = {})
        @bucket_name = settings[:bucket_name]
        @access_key_id = settings[:access_key_id]
        @secret_access_key = settings[:secret_access_key]
        @connection = try_connect
      end
      
      # Returns the buckets available from S3
      def collections
        @connection.list_bucket.select(:key)
      end
      
      # Copies the remote resource to the local filesystem
      # @param [String] the remote name of the resource to copy
      # @param [String] the local name of the destination
      def copy(from, to)
        open(to, 'w') do |file|
          @connection.get(bucket_name, self.class.key_name(from)) { |chunk| file.write(chunk) }
        end
        Cloudsync.logger.info "Completed download '#{to}'"
      end
      
      def connected?
        @connection_success
      end
      
      def volume
        @connection.bucket(bucket_name, true)
      end
      
      def write(file_path)
        @connection.put(bucket_name, self.class.key_name(file_path), File.open(file_path))
        Cloudsync.logger.info "Completed upload #{file_path}"
      end
      
      private
        def try_connect
          begin
            conn = RightAws::S3Interface.new(@access_key_id, @secret_access_key, {
              :multi_thread => true,
              :logger => Cloudsync.logger
            })
            @connection_success = true
            return conn
          rescue Exception => e
            @connection_success = false
            Cloudsync.logger.error "Could not establish connection with S3: '#{e.message}'"
          end
        end
      
    end
  end
end