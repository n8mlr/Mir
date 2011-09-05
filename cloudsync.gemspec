# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cloudsync/version"

Gem::Specification.new do |s|
  s.name        = "cloudsync"
  s.version     = Cloudsync.version
  s.authors     = ["Nate Miller"]
  s.email       = ["nate@natemiller.org"]
  s.homepage    = ""
  s.summary     = %q{A utility for backing up resources}
  s.description = %q{A commandline tool useful for automating the back up of files to Amazon S3}

  s.rubyforge_project = "cloudsync"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
  
  s.add_runtime_dependency "bundler"
  s.add_runtime_dependency "right_aws"
  s.add_runtime_dependency "activerecord"
  s.add_runtime_dependency "activesupport"
  s.add_runtime_dependency "work_queue"
end
