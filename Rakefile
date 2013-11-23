require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :spec do
  task :all do
    %w(3.2 4.0 edge).each do |ar_version|
      system(
        {
          "BUNDLE_GEMFILE" => "spec/gemfiles/Gemfile.ar-#{ar_version}",
          "MYSQL" => "1"
        },
        "rspec"
      )
    end
  end
end
