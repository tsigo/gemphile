RACK_ENV = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'

# std lib
require 'json'

# bundled
require 'bundler/setup'
require 'delayed_job'
require 'delayed_job_mongoid'
require 'mongoid'
require 'sinatra/base'

# gemphile
require_relative 'helpers'
require_relative 'jobs/gemfile_job'
require_relative 'models/gem_count'
require_relative 'models/gem_entry'
require_relative 'models/payload'
require_relative 'models/repository'

Mongoid.configure do |config|
  config.master = Mongo::Connection.new.db("gemphile_#{RACK_ENV}")
  config.allow_dynamic_fields = false
  config.autocreate_indexes   = true unless RACK_ENV == 'production'
end
