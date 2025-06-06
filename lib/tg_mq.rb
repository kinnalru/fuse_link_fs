require 'logger'
require 'active_support/all'

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/tg-mq.rb")
loader.inflector.inflect(
  'tg_mq' => 'TgMq',
  'tg-mq' => 'TgMq'
)
loader.setup

module TgMq
  include Configuration::Concern

  def self.setup_logger(logger)
    logger.respond_to?(:tagged) ? logger : ActiveSupport::TaggedLogging.new(logger)
  end
end
