# The config class is used for storage of user settings and preferences releated to 
#   S3 storage
module Mir
  class UndefinedConfigValue < StandardError; end
    
  class Config
    
    # Creates a new config instance
    # @param config_file [String] path to the configuration file
    # @yield [Mir::Config]
    # @return [Mir::Config]
    def initialize(config_file = nil)
      @config_file = config_file
      @settings, @database = nil, nil
      
      self.max_upload_attempts = 10
      self.max_download_attempts = 10
      self.max_threads = 5
      
      yield self if block_given?
    end
    
    attr_accessor :max_upload_attempts, :max_download_attempts, :max_threads
    
    # Validates configuration settings
    # @todo move this into a class method responsible for parsing the YAML file. We
    #   shouldn't have to explicitly check for a valid object unless the user has provided
    #   a settings file
    def valid?
      if @config_file.nil? or !File.exist?(@config_file)
        Mir.logger.error("Configuration file not found")
        return false
      end
      
      if File.directory?(@config_file)
        Mir.logger.error("Received directory instead of settings file")
        return false
      end
      
      File.open(@config_file) do |f|
        yml = YAML::load(f)
        if yml.key? "settings"
          @settings = OpenStruct.new yml["settings"]
          @settings.database = symbolize_keys(@settings.database)
          @settings.cloud_provider = symbolize_keys(@settings.cloud_provider)
        else
          Mir.logger.error("Malformed config file")
          return false
        end
      end
      true
    end
    
    def method_missing(meth, *args, &block)
      val = @settings.send(meth)
      unless val.nil?
        val
      else
        raise UndefinedConfigValue
      end
    end
    
    private
      def symbolize_keys(hsh)
        symbolized = hsh.inject({}) do |opts, (k,v)|
          opts[(k.to_sym rescue k) || k] = v
          opts
        end
        symbolized
      end
    
  end
end