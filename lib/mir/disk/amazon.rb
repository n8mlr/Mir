require "right_aws"
require "tempfile"
require "digest/md5"

module Mir
  module Disk
    class Amazon
      
      # This is the default size in bytes at which files will be split and stored
      # on S3. From trial and error, 5MB seems to be a good default size for chunking
      # large files.
      DEFAULT_CHUNK_SIZE = 5*(2**20) 
      
      attr_reader :bucket_name, :connection
      
      #
      # Converts a path name to a key that can be stored on s3
      # 
      # @param [String] the path to the file
      # @return [String] an S3-safe key with leading slashes removed
      def self.s3_key(path)
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
        @chunk_size = settings[:chunk_size] || DEFAULT_CHUNK_SIZE
        @connection = try_connect
      end
      
      # Returns the buckets available from S3
      def collections
        @connection.list_bucket.select(:key)
      end
      
      def chunk_size=(n)
        raise ArgumentError unless n > 0
        @chunk_size = n
      end
      
      def chunk_size
        @chunk_size
      end
      
      # Whether the key exists in S3
      # 
      # @param [String] the S3 key name
      # @return [Boolean]
      def key_exists?(key)
        begin
          connection.head(bucket_name, key)
        rescue RightAws::AwsError => e
          return false
        end

        true
      end
      
      # Copies the remote resource to the local filesystem
      # @param [String] the remote name of the resource to copy
      # @param [String] the local name of the destination
      def copy(from, dest)
        open(dest, 'w') do |file|
          key = self.class.s3_key(from)
          remote_file = MultiPartFile.new(self, key)
          remote_file.get(dest)
        end
      end
      
      # Retrieves the complete object from S3 without streaming
      def read(key)
        connection.get_object(bucket_name, key)
      end
      
      def connected?
        @connection_success
      end
      
      def volume
        connection.bucket(bucket_name, true)
      end
      
      # Deletes the remote version of the file
      # @return [Boolean] true if operation succeeded
      def delete(file_path)
        key = self.class.s3_key(file_path)
        Mir.logger.info "Deleting remote object #{file_path}"

        begin
          remote_file = MultiPartFile.new(self, key)
        rescue Disk::RemoteFileNotFound => e
          Mir.logger.warn "Could not find remote resource '#{key}'"
          return false
        end
        
        if remote_file.multipart?
          delete_parts(key)
        else
          connection.delete(bucket_name, key)
        end
      end
      
      # Writes a file to Amazon S3. If the file size exceeds the chunk size, the file will
      # be written in chunks
      # 
      # @param [String] the absolute path of the file to be written
      # @raise [Disk::IncompleteTransmission] raised when remote resource is different from local file
      def write(file_path)
        key = self.class.s3_key(file_path)
        
        if File.size(file_path) <= chunk_size
          connection.put(bucket_name, key, open(file_path))
          raise Disk::IncompleteTransmission unless equals?(file_path, key)
        else          
          delete_parts(file_path) # clean up remaining part files if any exist
                    
          open(file_path, "rb") do |source|
            part_id = 1
            while part = source.read(chunk_size) do
              part_name = Mir::Utils.filename_with_sequence(key, part_id)
              Mir.logger.debug "Writing part #{part_name}"
              
              temp_file(part_name) do |tmp|
                tmp.binmode                
                tmp.write(part)
                tmp.rewind
                connection.put(bucket_name, part_name, open(tmp.path))
                raise Disk::IncompleteTransmission unless equals?(tmp.path, part_name)
              end

              part_id += 1
            end
          end
        end
        Mir.logger.info "Completed upload #{file_path}"
      end
      
      private
      
      # Determines whether a local file matches the remote file
      #
      # @param [String] the complete path name to the file
      # @param [String] the S3 key name for the object
      # @return [Boolean] whether the MD5 hash of the local file matches the remote value
      def equals?(filename, key)
        meta_ob = connection.retrieve_object(:bucket => bucket_name, :key => key)
        remote_md5 = meta_ob[:headers]["etag"].slice(4..-5)
        Digest::MD5.file(filename).to_s == remote_md5
      end
      
      def try_connect
        begin
          conn = RightAws::S3Interface.new(@access_key_id, @secret_access_key, {
            :multi_thread => true,
            :logger => Mir.logger
          })
          @connection_success = true
          return conn
        rescue Exception => e
          @connection_success = false
          Mir.logger.error "Could not establish connection with S3: '#{e.message}'"
        end
      end
      
      # Yields a temp file object that is immediately discarded after use
      #
      # @param [String] the filename
      # @yields [Tempfile]
      def temp_file(name, &block)          
        file = Tempfile.new(File.basename(name))
        begin
          yield file
        ensure
          file.close
          file.unlink
        end
      end
      
      # Used to delete a file that has been broken into chunks
      #
      # @return [Boolean] true if succeeded
      def delete_parts(file_path)
        flag = true
        connection.incrementally_list_bucket(bucket_name, 
                                            { :prefix => self.class.s3_key(file_path), 
                                              :max_keys => 100 }) do |group|
          
          group[:contents].each do |item|
            if connection.delete(bucket_name, item[:key])
              Mir.logger.debug("Deleted '#{item[:key]}'")
            else
              flag = false 
            end              
          end
        end
        flag
      end
    end
    
    # Used to hide the inner details of multipart file uploads and downloads. It is important
    # that this class does not throw any exceptions as these exceptions may be swallowed further
    # up the stack by worker threads
    class MultiPartFile
      
      # @param [Disk] the remote disk
      # @param [String] the name of the resource
      def initialize(disk, name)
        @disk, @name = disk, name
        multiname = Utils.filename_with_sequence(name, 1)
                  
        if disk.key_exists?(name)
          @multipart = false
        elsif disk.key_exists?(multiname)
          @multipart = true
        else
          raise Disk::RemoteFileNotFound
        end
      end
      
      attr_reader :disk, :name
      
      # Whether the resource is broken into chunks on the remote store
      def multipart?
        @multipart
      end
      
      # Downloads the resource to the destination. If the file is stored in parts it is download
      # sequentially in pieces
      def get(dest)
        output = File.new(dest, "wb")
        begin
          if multipart?
            seq = 1
            while part = Utils.filename_with_sequence(name, seq) do
              break unless disk.key_exists? part
              output.write disk.read(part)
              seq += 1
            end
          else
            output.write disk.read(name)
          end
        rescue Exception => e
          Mir.logger.error e
        ensure
          output.close
        end
      end
    end
    
  end
end