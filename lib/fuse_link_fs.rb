require 'logger'
require 'active_support/all'

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/fuse-link-fs.rb")
loader.inflector.inflect(
  'fuse_link_fs' => 'FuseLinkFs',
  'fuse-link-fs' => 'FuseLinkFs'
)
loader.setup

module FuseLinkFs
  include Configuration::Concern

  def self.setup_logger(logger)
    logger.respond_to?(:tagged) ? logger : ActiveSupport::TaggedLogging.new(logger)
  end
end
