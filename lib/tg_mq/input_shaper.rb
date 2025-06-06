module TgMq
  class InputShaper
    attr_reader :logger

    def initialize(logger: TgMq.config.logger)
      @logger = TgMq.setup_logger(logger).tagged(self.class)

      @frames = Hash.new do |h, message_id|
        h[message_id] = {
          buffer: '',
          frames: []
        }
      end
    end

    def pushdata(text)
      if (frame = Frame.parse(text))
        logger.info "receive frame [#{frame.id}]"
        frameset = @frames[frame.message_id]
        data = frameset[:buffer] += frame.chunk
        frameset[:frames] << frame

        if data.end_with?(Frame::END_MSG)
          @frames.delete(frame.message_id)
          return data[0..-5]
        end
      else
        logger.warn "skip [#{text.first(15)}]: not a frame"
      end

      nil
    end

  end
end
