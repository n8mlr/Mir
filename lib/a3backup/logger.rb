require 'logger'

module A3backup
  def self.logger=(logger)
    @@logger = logger
  end
  def self.logger
    @@logger
  end
end