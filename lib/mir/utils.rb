module Mir
  module Utils
    def self.try_create_dir(path)
      Dir.mkdir(path) unless Dir.exist?(path)
    end
    
    # Splits a file into pieces that may be reassembled later
    # @param [File or String] File to be split
    # @param [Integer] the number of bytes per each chunked file
    # @param [String] where the split files should be stored
    def self.split_file(file, chunk_size, dest)
      try_create_dir(dest) unless Dir.exist?(dest)
      
      fname = File.join(dest, File.basename(file))
      seq = 1
      
      open(file, "rb") do |f|
        while split_data = f.read(chunk_size) do
          split_name = [fname, "-", "%07d" % seq].join
          open(split_name, "wb") { |dest| dest.write(split_data) }
          seq += 1
        end
      end
    end
  
    
    # Recombines a file from pieces
    # @param [String] the directory that holds the split files
    # @param [String] the path to the assembled file
    def self.recombine(source_dir, dest)
      parts = Dir.glob(File.join(source_dir, "*"))
      open(File.expand_path(dest), "wb") do |file|
        parts.each do |part|
          p_io = File.new(part)
          file.write p_io.read
        end
      end
    end
  end
end