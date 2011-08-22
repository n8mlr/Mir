# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "a3backup/version"

Gem::Specification.new do |s|
  s.name        = "a3backup"
  s.version     = A3backup::VERSION
  s.authors     = ["Nate Miller"]
  s.email       = ["nate@natemiller.org"]
  s.homepage    = ""
  s.summary     = %q{A utility for backing up resources to S3}
  s.description = %q{A commandline tool useful for automating the back up of files to Amazon S3}

  s.rubyforge_project = "a3backup"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "aws-s3"
  s.add_runtime_dependency "sqlite3"
  s.add_runtime_dependency "activerecord"
  s.add_runtime_dependency "activesupport"
end
