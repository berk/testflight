# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
require 'testflight/version'
 
Gem::Specification.new do |spec|
  spec.name        = "testflight"
  spec.version     = Testflight::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.authors     = ["Michael Berkovich"]
  spec.email       = ["theiceberk@gmail.com"]
  spec.homepage    = "https://github.com/berk/testflight"
  spec.summary     = "iOS application deployment automation"
  spec.description = "Mechanism for building, packaging, tagging and deploying Xcode projects to testflightapp.com"
 
  spec.files        = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.rdoc)
  spec.executables  = spec.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  spec.test_files   = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_path = ['lib', 'lib/testflight']

  spec.add_runtime_dependency 'thor', '~> 0.16.0'
  spec.add_runtime_dependency 'rb-appscript', '~> 0.6.1'
  spec.add_dependency "plist", "~> 3.1.0"
end
