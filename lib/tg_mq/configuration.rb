require 'uri'

module TgMq
  class Configuration
    attr_accessor :logger

    def initialize(logger = ::Logger.new(STDOUT, formatter: Logger::Formatter.new))
      @logger = logger.respond_to?(:tagged) ? logger : ActiveSupport::TaggedLogging.new(logger)
    end

    module Concern
      extend ActiveSupport::Concern

      included do |_klass|
      end

      class_methods do
        # Instantiate the Configuration singleton
        # or return it. Remember that the instance
        # has attribute readers so that we can access
        # the configured values
        def configuration
          @configuration ||= TgMq::Configuration.new
        end

        def config
          configuration
        end

        # This is the configure block definition.
        # The configuration method will return the
        # Configuration singleton, which is then yielded
        # to the configure block. Then it's just a matter
        # of using the attribute accessors we previously defined
        def configure
          yield(configuration)
        end
      end
    end
  end
end
