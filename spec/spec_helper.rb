require "mir"

RSpec.configure do |config|
  Mir.logger = Logger.new($stdout)
  Mir.logger.level = Logger::ERROR
end