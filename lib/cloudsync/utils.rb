module Cloudsync
  module Utils
    def self.try_create_dir(path)
      Dir.mkdir(path) unless Dir.exist?(path)
    end
  end
end