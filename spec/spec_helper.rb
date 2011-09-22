require "mir"
require "mir/models/app_setting"
require "mir/models/resource"

RSpec.configure do |config|
  Mir.logger = Logger.new($stdout)
  Mir.logger.level = Logger::ERROR
end