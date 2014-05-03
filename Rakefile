# encoding: utf-8

require 'rake/testtask'
require 'rspec/core/rake_task'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '--color --format documentation'
end

task test_all: %w[test spec]

require 'coveralls/rake/task'

Coveralls::RakeTask.new
task :test_with_coveralls => [:test_all, 'coveralls:push']
