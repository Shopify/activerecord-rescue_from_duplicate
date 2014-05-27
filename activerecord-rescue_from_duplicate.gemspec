# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rescue_from_duplicate/active_record/version'

Gem::Specification.new do |spec|
  spec.name          = "activerecord-rescue_from_duplicate"
  spec.version       = Activerecord::RescueFromDuplicate::VERSION
  spec.authors       = ["Guillaume Malette"]
  spec.email         = ["guillaume@jadedpixel.com"]
  spec.description   = %q{Rescue from MySQL and Sqlite duplicate errors}
  spec.summary       = %q{Rescue from MySQL and Sqlite duplicate errors when trying to insert records that fail uniqueness validation}
  spec.homepage      = "https://github.com/Shopify/activerecord-rescue_from_duplicate"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'activerecord', '>= 3.2'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'mysql2'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'pry'
end
