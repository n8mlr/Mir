require "a3backup/application"
require "a3backup/config"
require "a3backup/disk"
require "a3backup/disk/amazon"
require "a3backup/index"
require "a3backup/logger"
require "a3backup/options"
require "a3backup/utils"
require "a3backup/version"

require "aws/s3"
require 'ostruct'
require 'yaml'
require 'optparse'
require 'ostruct'

module A3backup
end