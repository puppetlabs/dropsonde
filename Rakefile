require 'bundler'
require 'puppet_litmus/rake_tasks' if Bundler.rubygems.find_name('puppet_litmus').any?
require 'puppetlabs_spec_helper/rake_tasks'

task :default do
  system("rake -T")
end

require 'rspec/core/rake_task'
namespace :dropsonde do
  RSpec::Core::RakeTask.new(:acceptance) do |t|
    t.pattern = 'spec/acceptance/**{,/*/**}/*_spec.rb'
  end
end
