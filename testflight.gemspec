# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
require 'testflight/version'
 
Gem::Specification.new do |s|
  s.name        = "testflight"
  s.version     = Testflight::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Michael Berkovich"]
  s.email       = ["theiceberk@gmail.com"]
  s.homepage    = "https://github.com/berk/testflight"
  s.summary     = "iOS application deployment automation"
  s.description = "Mechanism for building, packaging, tagging and deploying XCode projects to testflightapp.com"
 
  s.files        = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md)
  s.executables  = ['takeoff']
  s.require_path = 'lib'

  s.add_dependency "plist", "~> 3.1.0"
end
