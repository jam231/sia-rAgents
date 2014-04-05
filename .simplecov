require 'simplecov'
require 'coveralls'


SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
   # Exclude Benchmarking dir from simplecov and coveralls statistics
   add_filter 'Benchmarking/'
end