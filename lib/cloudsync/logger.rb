require 'logger'

module Cloudsync
  def self.logger=(logger)
    @@logger = logger
  end
  def self.logger
    @@logger
  end
end