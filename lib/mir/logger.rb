require 'logger'

module Mir
  # Assigns a global logger
  # @param logger [Logger]
  def self.logger=(logger)
    @@logger = logger
  end
  
  # Returns the global logger instance
  # @return [Logger]
  def self.logger
    @@logger
  end
end