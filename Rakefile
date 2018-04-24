require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :spec do
  task :all do
    Dir[File.expand_path('../gemfiles/*.lock', __FILE__)].each { |f| File.delete(f) }
    Dir[File.expand_path('../gemfiles/*', __FILE__)].each do |gemfile|
      env = { 'BUNDLE_GEMFILE' => gemfile }
      system(env, 'bundle install')
      system(env, 'bundle exec rspec')
    end
  end
end
