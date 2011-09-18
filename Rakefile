require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the acts_as_dag plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the acts_as_dag plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'ActsAsDag'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/dag/dag.rb')
end

# setup to build plugin as a gem
begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "acts-as-dag"
    gemspec.summary = "Acts As DAG Gem"
    gemspec.description = "Acts As Dag, short for Acts As Directed Acyclic Graph, is a gem which allows you to represent DAG hierarchy using your ActiveRecord models. Versions 1.x were built using Rails 2.x. Versions 2.x were built using Rails 3.x."
    gemspec.authors = ["Matthew Leventi", "Robert Schmitt"]
    gemspec.email = "forever@thelongterm.net"
    gemspec.rubyforge_project = "acts-as-dag"
    gemspec.homepage = "http://github.com/resgraph/acts-as-dag"
    gemspec.files = FileList["[A-Z]*", "{lib,test}/**/*"]
  end
rescue
  puts "Jeweler or one of its dependencies is not installed."
end
