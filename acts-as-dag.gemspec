# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "acts-as-dag/version"

Gem::Specification.new do |s|
  s.name        = "acts-as-dag"
  s.version     = Acts::As::Dag::VERSION
  s.authors     = ['Matthew Leventi', 'Robert Schmitt']
  s.email       = ["resgraph@cox.net"]
  s.homepage    = 'https://github.com/resgraph/acts-as-dag'
  s.summary     = %q{Directed Acyclic Graph hierarchy for Rail's ActiveRecord}
  s.description = %q{Directed Acyclic Graph hierarchy for Rail's ActiveRecord, supporting Rails 4.x}

  s.rubyforge_project = "acts-as-dag"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # As specified in test/dag_test.rb
  s.add_development_dependency 'rake'
  s.add_development_dependency 'sqlite3'
  s.add_runtime_dependency 'activemodel'
  s.add_runtime_dependency 'activerecord', '>= 4.0.0'
end
