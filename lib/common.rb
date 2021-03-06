# common.rb - Common settings, requires and helpers
unless defined? TOURBUS_LIB_PATH
  TOURBUS_LIB_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
  $:<< TOURBUS_LIB_PATH unless $:.include? TOURBUS_LIB_PATH
end

require 'rubygems'

gem 'webrat', ">= 0.7.0"
gem 'mechanize', ">= 1.0.0"
gem 'trollop', ">= 1.10.0"
gem 'faker', '>= 0.3.1'

# TODO: I'd like to remove dependency on Rails. Need to see what all
# we're using (like classify) and remove each dependency individually.
require 'activesupport'

require 'monitor'
require 'faker'
require 'tour_bus'
require 'runner'
require 'tour'
require 'output'

Dir["#{File.dirname(__FILE__)}/output/*.rb"].each { |f| require(f) }

class TourBusException < Exception; end

def require_all_files_in_folder(folder, extension = "*.rb")
  for file in Dir[File.join('.', folder, "**/#{extension}")]
    require file
  end
end

