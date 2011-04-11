$:.unshift File.expand_path("../../lib", File.dirname(__FILE__))

require 'gemfile_reader'

module SpecHelpers
  def gemfile(name)
    File.expand_path("./fixtures/#{name}.rb", File.dirname(__FILE__))
  end

  # Assumes `let(:gems)` has been defined
  def find_gem(name)
    return unless gems
    gems.find { |g| g.name == name }
  end
end

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.include SpecHelpers
end