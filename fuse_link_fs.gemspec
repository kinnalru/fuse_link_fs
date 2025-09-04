# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fuse_link_fs/version'

Gem::Specification.new do |spec|
  spec.name          = 'fuse_link_fs'
  spec.version       = ENV['BUILDVERSION'].to_i > 0 ? "#{FuseLinkFs::VERSION}.#{ENV['BUILDVERSION'].to_i}" : FuseLinkFs::VERSION
  spec.authors       = ['Samoilenko Yuri']
  spec.email         = ['kinnalru@gmail.com']

  spec.summary       = 'Fuse Filesystem backed by link shortify'
  spec.description   = 'Fuse Filesystem backed by link shortify'

  spec.files         = Dir['bin/*', 'lib/**/*', 'Gemfile*', 'LICENSE.txt', 'README.md', '*.gemspec']
  spec.bindir        = 'bin'
  spec.require_paths = ['lib']
  spec.executables   = ['fuselinkfs']

  spec.add_runtime_dependency 'activesupport', '~> 6.0'
  spec.add_runtime_dependency 'logger'
  spec.add_runtime_dependency 'ffi-libfuse'
  spec.add_runtime_dependency 'zeitwerk'
  spec.add_runtime_dependency 'socksify'
  
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec_junit_formatter'

  spec.add_development_dependency 'byebug'
end
