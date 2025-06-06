# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tg_mq/version'

Gem::Specification.new do |spec|
  spec.name          = 'tg_mq'
  spec.version       = ENV['BUILDVERSION'].to_i > 0 ? "#{TgMq::VERSION}.#{ENV['BUILDVERSION'].to_i}" : TgMq::VERSION
  spec.authors       = ['Samoilenko Yuri']
  spec.email         = ['kinnalru@gmail.com']

  spec.summary       = 'Message Queue backed by Telegram Chat'
  spec.description   = 'Message Queue backed by Telegram Chat'

  spec.files         = Dir['bin/*', 'lib/**/*', 'Gemfile*', 'LICENSE.txt', 'README.md']
  spec.bindir        = 'bin'
  spec.require_paths = ['lib']
  spec.executables   = ['tgmq']

  spec.add_runtime_dependency 'activesupport', '~> 6.0'
  spec.add_runtime_dependency 'logger'
  spec.add_runtime_dependency 'timeouter'
  spec.add_runtime_dependency 'telegram-bot-ruby'
  spec.add_runtime_dependency 'zeitwerk'

  spec.add_development_dependency 'byebug'
end
