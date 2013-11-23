require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :spec do
  task :all do
    %w(3.2).each do |ar_version|
      command = %W{
        BUNDLE_GEMFILE=spec/gemfiles/Gemfile.ar-#{ar_version}
        MYSQL=1
        POSTGRES=1
        rspec
      }.join(' ')
      puts command
      puts `#{command}`
    end
  end
end
